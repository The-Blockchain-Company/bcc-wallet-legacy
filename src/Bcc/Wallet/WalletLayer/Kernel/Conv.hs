{-# LANGUAGE LambdaCase #-}
-- | Convert to and from V1 types
module Bcc.Wallet.WalletLayer.Kernel.Conv (
    -- * From V1 to kernel types
    fromRootId
  , fromAccountId
  , fromAssuranceLevel
  , fromRedemptionCode
  , fromRedemptionCodePaper
    -- * From kernel types to V1 types
  , toAccountId
  , toRootId
  , toAccount
  , toWallet
  , toEosWallet
  , toAddress
  , toCardanoAddress
  , toAssuranceLevel
  , toSyncState
  , toInputGrouping
    -- * Custom errors
  , InvalidRedemptionCode(..)
    -- * Convenience re-exports
  , runExcept
  , runExceptT
  , withExceptT
  , exceptT
  ) where

import           Universum

import qualified Prelude

import           Control.Lens (to)
import           Control.Monad.Except
import           Crypto.Error (CryptoError)
import           Data.ByteString.Base58 (bitcoinAlphabet, decodeBase58)
import           Formatting (bprint, build, formatToString, sformat, shown, (%))
import qualified Formatting.Buildable
import qualified Serokell.Util.Base64 as B64

import           Pos.Client.Txp.Util (InputSelectionPolicy (..))
import           Pos.Core (Address, BlockCount (..))
import           Pos.Crypto (AesKey, RedeemSecretKey, aesDecrypt,
                     redeemDeterministicKeyGen)

import           Bcc.Mnemonic (mnemonicToAesKey)
import           Bcc.Wallet.API.Types.UnitOfMeasure
import qualified Bcc.Wallet.API.V1.Types as V1
import           Bcc.Wallet.Kernel.AddressPoolGap (AddressPoolGap)
import           Bcc.Wallet.Kernel.CoinSelection.FromGeneric
                     (InputGrouping (..))
import           Bcc.Wallet.Kernel.DB.BlockMeta (addressMetaIsUsed)
import qualified Bcc.Wallet.Kernel.DB.HdRootId as HD
import qualified Bcc.Wallet.Kernel.DB.HdWallet as HD
import           Bcc.Wallet.Kernel.DB.InDb (fromDb)
import           Bcc.Wallet.Kernel.DB.Spec (cpAddressMeta)
import           Bcc.Wallet.Kernel.DB.Spec.Read
import           Bcc.Wallet.Kernel.DB.Util.IxSet (ixedIndexed)
import qualified Bcc.Wallet.Kernel.DB.Util.IxSet as IxSet
import           Bcc.Wallet.Kernel.Internal (WalletRestorationProgress,
                     wrpCurrentSlot, wrpTargetSlot, wrpThroughput)
import qualified Bcc.Wallet.Kernel.Read as Kernel
import           UTxO.Util (exceptT)
-- import           Bcc.Wallet.WalletLayer (InvalidRedemptionCode (..))

-- Functions 'toWallet' and 'toEosWallet' contain duplications in 'where'
-- sections, but in order to fix it we should change two functions and
-- introduce the new one.
{-# ANN module ("HLint: ignore Reduce duplication" :: Text) #-}

{-------------------------------------------------------------------------------
  From V1 to kernel types

  Nomenclature based on kernel names, not V1 names.
-------------------------------------------------------------------------------}

fromRootId :: Monad m => V1.WalletId -> ExceptT Text m HD.HdRootId
fromRootId (V1.WalletId wId) = exceptT $ maybe
    (Left $ "fromRootId: can't decode given Text to HdRootId: " <> wId)
    Right
    (HD.decodeHdRootId wId)

fromAccountId :: Monad m
              => V1.WalletId -> V1.AccountIndex -> ExceptT Text m HD.HdAccountId
fromAccountId wId accIx =
    aux <$> fromRootId wId
  where
    aux :: HD.HdRootId -> HD.HdAccountId
    aux hdRootId = HD.HdAccountId hdRootId (HD.HdAccountIx $ V1.getAccIndex accIx)

-- | Converts from the @V1@ 'AssuranceLevel' to the HD one.
fromAssuranceLevel :: V1.AssuranceLevel -> HD.AssuranceLevel
fromAssuranceLevel V1.NormalAssurance = HD.AssuranceLevelNormal
fromAssuranceLevel V1.StrictAssurance = HD.AssuranceLevelStrict

-- | Decode redemption key for non-paper wallet
--
-- See also comments for 'fromRedemptionCodePaper'.
fromRedemptionCode :: Monad m
                   => V1.ShieldedRedemptionCode
                   -> ExceptT InvalidRedemptionCode m RedeemSecretKey
fromRedemptionCode (V1.ShieldedRedemptionCode crSeed) = do
    bs <- withExceptT (const $ InvalidRedemptionCodeInvalidBase64 crSeed) $
            asum [ exceptT $ B64.decode    crSeed
                 , exceptT $ B64.decodeUrl crSeed
                 ]
    exceptT $ maybe (Left $ InvalidRedemptionCodeNot32Bytes crSeed) (Right . snd) $
      redeemDeterministicKeyGen bs

-- | Decode redemption key for paper wallet
--
-- NOTE: Although both 'fromRedemptionCode' and 'fromRedemptionCodePaper' both
-- take a 'V1.ShieldedRedemptionCode' as argument, note that for paper wallets
-- this must be Base58 encoded, whereas for 'fromRedemptionCode' it must be
-- Base64 encoded.
fromRedemptionCodePaper :: Monad m
                        => V1.ShieldedRedemptionCode
                        -> V1.RedemptionMnemonic
                        -> ExceptT InvalidRedemptionCode m RedeemSecretKey
fromRedemptionCodePaper (V1.ShieldedRedemptionCode pvSeed)
                        (V1.RedemptionMnemonic pvBackupPhrase) = do
    encBS <- exceptT $ maybe (Left $ InvalidRedemptionCodeInvalidBase58 pvSeed) Right $
               decodeBase58 bitcoinAlphabet $ encodeUtf8 pvSeed
    decBS <- withExceptT InvalidRedemptionCodeCryptoError $ exceptT $
               aesDecrypt encBS aesKey
    exceptT $ maybe (Left $ InvalidRedemptionCodeNot32Bytes pvSeed) (Right . snd) $
      redeemDeterministicKeyGen decBS
  where
    aesKey :: AesKey
    aesKey = mnemonicToAesKey pvBackupPhrase

{-------------------------------------------------------------------------------
  From kernel to V1 types
-------------------------------------------------------------------------------}

toAccountId :: HD.HdAccountId -> V1.AccountIndex
toAccountId =
    V1.unsafeMkAccountIndex -- Invariant: Assuming HD AccountId are valid
    . HD.getHdAccountIx
    . view HD.hdAccountIdIx

toRootId :: HD.HdRootId -> V1.WalletId
toRootId = V1.WalletId . sformat build

-- | Converts a Kernel 'HdAccount' into a V1 'Account'.
--
toAccount :: Kernel.DB -> HD.HdAccount -> V1.Account
toAccount snapshot account = V1.Account {
      accIndex     = accountIndex
    , accAddresses = map (toAddress account . view ixedIndexed) addresses
    , accAmount    = V1.WalletCoin accountAvailableBalance
    , accName      = account ^. HD.hdAccountName . to HD.getAccountName
    , accWalletId  = V1.WalletId (sformat build hdRootId)
    }
  where
    -- NOTE(adn): Perhaps we want the minimum or expected balance here?
    accountAvailableBalance = account ^. HD.hdAccountState . HD.hdAccountStateCurrent (to cpAvailableBalance)
    hdAccountId  = account ^. HD.hdAccountId
    accountIndex = toAccountId (account ^. HD.hdAccountId)
    hdAddresses  = Kernel.addressesByAccountId snapshot hdAccountId
    addresses    = IxSet.toList hdAddresses
    hdRootId     = account ^. HD.hdAccountId . HD.hdAccountIdParent

-- | Converts an 'HdRoot' into a V1 'Wallet.
toWallet :: Kernel.DB -> HD.HdRoot -> V1.Wallet
toWallet db hdRoot = V1.Wallet {
      walId                         = (V1.WalletId walletId)
    , walName                       = hdRoot ^. HD.hdRootName
                                              . to HD.getWalletName
    , walBalance                    = V1.WalletCoin (Kernel.rootTotalBalance db rootId)
    , walHasSpendingPassword        = hasSpendingPassword
    , walSpendingPasswordLastUpdate = V1.WalletTimestamp lastUpdate
    , walCreatedAt                  = V1.WalletTimestamp createdAt
    , walAssuranceLevel             = v1AssuranceLevel
    , walSyncState                  = V1.Synced
    }
  where
    (hasSpendingPassword, lastUpdate) =
        case hdRoot ^. HD.hdRootHasPassword of
             HD.NoSpendingPassword lr  -> (False, lr ^. fromDb)
             HD.HasSpendingPassword lu -> (True, lu ^. fromDb)
    -- In case the wallet has no spending password, its last update
    -- matches this wallet creation time.
    rootId           = hdRoot ^. HD.hdRootId
    createdAt        = hdRoot ^. HD.hdRootCreatedAt . fromDb
    walletId         = sformat build rootId
    v1AssuranceLevel = toAssuranceLevel $ hdRoot ^. HD.hdRootAssurance

-- | Converts an 'HdRoot' into a V1 'EosWallet'.
toEosWallet :: Kernel.DB -> HD.HdRoot -> AddressPoolGap -> V1.EosWallet
toEosWallet db hdRoot gap = V1.EosWallet {
      eoswalId = V1.WalletId walletId
    , eoswalName = hdRoot ^. HD.hdRootName . to HD.getWalletName
    , eoswalAddressPoolGap = gap
    , eoswalBalance = V1.WalletCoin (Kernel.rootTotalBalance db rootId)
    , eoswalCreatedAt = V1.WalletTimestamp createdAt
    , eoswalAssuranceLevel = v1AssuranceLevel
    }
  where
    rootId = hdRoot ^. HD.hdRootId
    createdAt = hdRoot ^. HD.hdRootCreatedAt . fromDb
    walletId = sformat build rootId
    v1AssuranceLevel = toAssuranceLevel $ hdRoot ^. HD.hdRootAssurance

toAssuranceLevel :: HD.AssuranceLevel -> V1.AssuranceLevel
toAssuranceLevel HD.AssuranceLevelNormal = V1.NormalAssurance
toAssuranceLevel HD.AssuranceLevelStrict = V1.StrictAssurance

-- | Converts a Kernel 'HdAddress' into a V1 'WalletAddress'.
toAddress :: HD.HdAccount -> HD.HdAddress -> V1.WalletAddress
toAddress acc hdAddress =
    V1.WalletAddress (V1.WalAddress cardanoAddress)
                     (addressMeta ^. addressMetaIsUsed)
                     addressOwnership
  where
    cardanoAddress   = hdAddress ^. HD.hdAddressAddress . fromDb
    addressMeta      = acc ^. HD.hdAccountState . HD.hdAccountStateCurrentCombined (<>) (cpAddressMeta cardanoAddress)
    -- NOTE
    -- In this particular case, the address had to be known by us. As a matter
    -- of fact, to construct a 'WalletAddress', we have to be aware of pieces
    -- of informations we can only have if the address is ours (like the
    -- parent's account derivation index required to build the 'HdAddress' in
    -- a first place)!
    addressOwnership = V1.AddressIsOurs

-- | Converts a Kernel 'HdAddress' into a Bcc 'Address'.
toCardanoAddress :: HD.HdAddress -> Address
toCardanoAddress hdAddr = hdAddr ^. HD.hdAddressAddress . fromDb

{-------------------------------------------------------------------------------
  Custom errors
-------------------------------------------------------------------------------}

data InvalidRedemptionCode =
    -- | Seed is invalid base64(url) (used for non-paper wallets)
    InvalidRedemptionCodeInvalidBase64 Text

    -- | Seed is invalid base58 (used for paper wallets)
  | InvalidRedemptionCodeInvalidBase58 Text

    -- | AES decryption error (for paper wallets)
  | InvalidRedemptionCodeCryptoError CryptoError

    -- | Seed is not 32-bytes long (for either paper or non-paper wallets)
    --
    -- NOTE: For paper wallets the seed is actually AES encrypted so the
    -- length would be hard to verify simply by inspecting this text.
  | InvalidRedemptionCodeNot32Bytes Text

instance Buildable InvalidRedemptionCode where
    build (InvalidRedemptionCodeInvalidBase64 txt) =
        bprint ("InvalidRedemptionCodeInvalidBase64 " % build) txt
    build (InvalidRedemptionCodeInvalidBase58 txt) =
        bprint ("InvalidRedemptionCodeInvalidBase58 " % build) txt
    build (InvalidRedemptionCodeCryptoError err) =
        bprint ("InvalidRedemptionCodeCryptoError " % shown) err
    build (InvalidRedemptionCodeNot32Bytes txt) =
        bprint ("InvalidRedemptionCodeNot32Bytes " % build) txt

instance Show InvalidRedemptionCode where
    show = formatToString build

-- | Calculate the 'SyncState' from data about the wallet's restoration.
toSyncState :: Maybe WalletRestorationProgress -> V1.SyncState
toSyncState = \case
    Nothing   -> V1.Synced
    Just info -> let MeasuredIn (BlockCount blocksPerSec) = info ^. wrpThroughput
      in V1.Restoring $
           V1.SyncProgress
             { spEstimatedCompletionTime =
                     let blocksToGo = (info ^. wrpTargetSlot) - (info ^. wrpCurrentSlot)
                         bps = max blocksPerSec 1
                     in V1.mkEstimatedCompletionTime (fromIntegral ((1000 * blocksToGo) `div` bps))
             , spThroughput = V1.mkSyncThroughput (BlockCount blocksPerSec)
             , spPercentage =
                     let tgtSlot = info ^. wrpTargetSlot
                         pct = if tgtSlot /= 0
                               then (100 * (info ^. wrpCurrentSlot)) `div` tgtSlot
                               else 0
                     in V1.mkSyncPercentage (fromIntegral pct)
             }

-- Matches the input InputGroupingPolicy with the Kernel's 'InputGrouping'
toInputGrouping :: V1.WalletInputSelectionPolicy -> InputGrouping
toInputGrouping (V1.WalletInputSelectionPolicy policy) = case policy of
    OptimizeForSecurity       -> PreferGrouping
    OptimizeForHighThroughput -> IgnoreGrouping
