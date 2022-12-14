module Bcc.Wallet.Kernel.Accounts (
      createAccount
    , deleteAccount
    , updateAccount
    , updateAccountGap
    -- * Errors
    , CreateAccountError(..)
    ) where

import qualified Prelude
import           Universum

import           Formatting (bprint, build, formatToString, (%))
import qualified Formatting as F
import qualified Formatting.Buildable
import           System.Random.MWC (GenIO, createSystemRandom, uniformR)

import           Data.Acid (update)

import           Pos.Core.NetworkMagic (makeNetworkMagic)
import           Pos.Crypto (EncryptedSecretKey, PassPhrase)

import           Bcc.Wallet.Kernel.AddressPoolGap (AddressPoolGap)
import           Bcc.Wallet.Kernel.DB.AcidState (CreateHdAccount (..), DB,
                     DeleteHdAccount (..), UpdateHdAccountGap (..),
                     UpdateHdAccountName (..))
import           Bcc.Wallet.Kernel.DB.HdRootId (HdRootId)
import           Bcc.Wallet.Kernel.DB.HdWallet (AccountName (..),
                     HdAccount (..), HdAccountBase (..), HdAccountId (..),
                     HdAccountIx (..), HdAccountState (..),
                     HdAccountUpToDate (..), UnknownHdAccount (..),
                     UpdateGapError (..), hdAccountName)
import           Bcc.Wallet.Kernel.DB.HdWallet.Create
                     (CreateHdAccountError (..), initHdAccount)
import           Bcc.Wallet.Kernel.DB.HdWallet.Derivation
                     (HardeningMode (..), deriveIndex)
import           Bcc.Wallet.Kernel.DB.Spec (Checkpoints (..),
                     initCheckpoint)
import           Bcc.Wallet.Kernel.Internal (PassiveWallet, walletKeystore,
                     walletProtocolMagic, wallets)
import qualified Bcc.Wallet.Kernel.Keystore as Keystore

import           Test.QuickCheck (Arbitrary (..), oneof)

data CreateAccountError =
      CreateAccountUnknownHdRoot HdRootId
      -- ^ When trying to create the 'Account', the parent 'HdRoot' was not
      -- there.
    | CreateAccountKeystoreNotFound HdRootId
      -- ^ When trying to create the 'Account', the 'Keystore' didn't have
      -- any secret associated with the input HdRootId.
    | CreateAccountHdRndAccountSpaceSaturated HdRootId
      -- ^ The available number of HD accounts in use is such that trying
      -- to find another random index would be too expensive.
    deriving Eq

instance Arbitrary CreateAccountError where
    arbitrary = oneof
        [ CreateAccountUnknownHdRoot <$> arbitrary
        , CreateAccountKeystoreNotFound <$> arbitrary
        , CreateAccountHdRndAccountSpaceSaturated <$> arbitrary
        ]

instance Buildable CreateAccountError where
    build (CreateAccountUnknownHdRoot uRoot) =
        bprint ("CreateAccountUnknownHdRoot " % F.build) uRoot
    build (CreateAccountKeystoreNotFound accId) =
        bprint ("CreateAccountKeystoreNotFound " % F.build) accId
    build (CreateAccountHdRndAccountSpaceSaturated hdAcc) =
        bprint ("CreateAccountHdRndAccountSpaceSaturated " % F.build) hdAcc

instance Show CreateAccountError where
    show = formatToString build

-- | Creates a new 'Account' for the input wallet.
-- Note: @it does not@ generate a new 'Address' to go in tandem with this
-- 'Account'. This will be responsibility of the wallet layer.
createAccount :: PassPhrase
              -- ^ The 'Passphrase' (a.k.a the \"Spending Password\").
              -> AccountName
              -- ^ The name for this account.
              -> HdRootId
              -- ^ An abstract notion of a 'Wallet identifier
              -> PassiveWallet
              -> IO (Either CreateAccountError (DB, HdAccount))
createAccount spendingPassword accountName hdRootId pw = do
    let nm = makeNetworkMagic (pw ^. walletProtocolMagic)
        keystore = pw ^. walletKeystore
    mbEsk <- Keystore.lookup nm hdRootId keystore
    case mbEsk of
         Nothing  -> return (Left $ CreateAccountKeystoreNotFound hdRootId)
         Just esk ->
             createHdRndAccount spendingPassword
                                accountName
                                esk
                                hdRootId
                                pw

-- | Creates a new 'Account' using the random HD derivation under the hood.
-- This code follows the same pattern of 'createHdRndAddress', but the two
-- functions are "similarly different" enough to not make convenient generalise
-- the code.
createHdRndAccount :: PassPhrase
                   -> AccountName
                   -> EncryptedSecretKey
                   -> HdRootId
                   -> PassiveWallet
                   -> IO (Either CreateAccountError (DB, HdAccount))
createHdRndAccount _spendingPassword accountName _esk rootId pw = do
    gen <- createSystemRandom
    go gen 0
    where
        go :: GenIO -> Word32 -> IO (Either CreateAccountError (DB, HdAccount))
        go gen collisions =
            case collisions >= maxAllowedCollisions of
                 True  -> return $ Left (CreateAccountHdRndAccountSpaceSaturated rootId)
                 False -> tryGenerateAccount gen collisions

        tryGenerateAccount :: GenIO
                           -> Word32
                           -- ^ The current number of collisions
                           -> IO (Either CreateAccountError (DB, HdAccount))
        tryGenerateAccount gen collisions = do
            newIndex <- deriveIndex (flip uniformR gen) HdAccountIx HardDerivation
            let hdAccountId = HdAccountId rootId newIndex
                newAccount  = initHdAccount (HdAccountBaseFO hdAccountId) initState &
                              hdAccountName .~ accountName
                db = pw ^. wallets
            res <- update db (CreateHdAccount newAccount)
            case res of
                 (Left (CreateHdAccountExists _)) ->
                     go gen (succ collisions)
                 (Left (CreateHdAccountUnknownRoot _)) ->
                     return (Left $ CreateAccountUnknownHdRoot rootId)
                 Right (db', ()) -> return (Right (db', newAccount))

        -- The maximum number of allowed collisions. This number was
        -- empirically calculated based on a [beta distribution](https://en.wikipedia.org/wiki/Beta_distribution).
        -- In particular, it can be shown how even picking small values for
        -- @alpha@ and @beta@, the probability of failing after the next
        -- collision rapidly approaches 99%. With 50 attempts, our probability
        -- to fail is 98%, and the 42 is a nice easter egg very close to 50,
        -- this is why it was picked.
        maxAllowedCollisions :: Word32
        maxAllowedCollisions = 42

        -- Initial account state
        initState :: HdAccountState
        initState = HdAccountStateUpToDate HdAccountUpToDate {
              _hdUpToDateCheckpoints = Checkpoints . one $ initCheckpoint mempty
            }

-- | Deletes an HD 'Account' from the data storage.
deleteAccount :: HdAccountId
              -> PassiveWallet
              -> IO (Either UnknownHdAccount ())
deleteAccount hdAccountId pw = do
    res <- liftIO $ update (pw ^. wallets) (DeleteHdAccount hdAccountId)
    return $ case res of
         Left dbErr -> Left dbErr
         Right ()   -> Right ()

-- | Updates an HD 'Account'.
updateAccount :: HdAccountId
              -> AccountName
              -- ^ The new name for this account.
              -> PassiveWallet
              -> IO (Either UnknownHdAccount (DB, HdAccount))
updateAccount hdAccountId newAccountName pw = do
    res <- liftIO $ update (pw ^. wallets) (UpdateHdAccountName hdAccountId newAccountName)
    return $ case res of
         Left dbError        -> Left dbError
         Right (db, account) -> Right (db, account)

-- | Updates address pool gap in an HD 'Account' (in EOS-wallet).
updateAccountGap
    :: HdAccountId
    -> AddressPoolGap
    -- ^ The new adress pool gap for this account.
    -> PassiveWallet
    -> IO (Either UpdateGapError (DB, HdAccount))
updateAccountGap hdAccountId newGap pw = liftIO $
    update (pw ^. wallets) (UpdateHdAccountGap hdAccountId newGap)
