{-# LANGUAGE RankNTypes #-}

-- | CREATE operations on HD wallets
module Bcc.Wallet.Kernel.DB.HdWallet.Create (
    -- * Errors
    CreateHdRootError(..)
  , CreateHdAccountError(..)
  , CreateHdAddressError(..)
    -- * Functions
  , createHdRoot
  , createHdAccount
  , createHdAddress
    -- * Initial values
  , initHdRoot
  , initHdAccount
  ) where

import           Universum

import           Control.Lens (at, (+~), (.=))
import           Data.SafeCopy (base, deriveSafeCopy)

import           Formatting (bprint, build, sformat, (%))
import qualified Formatting.Buildable

import qualified Pos.Core as Core

import           Bcc.Wallet.Kernel.DB.HdRootId (HdRootId)
import           Bcc.Wallet.Kernel.DB.HdWallet
import           Bcc.Wallet.Kernel.DB.InDb
import           Bcc.Wallet.Kernel.DB.Util.AcidState
import           Bcc.Wallet.Kernel.DB.Util.IxSet (AutoIncrementKey (..),
                     Indexed (..))
import qualified Bcc.Wallet.Kernel.DB.Util.IxSet as IxSet

{-------------------------------------------------------------------------------
  Errors
-------------------------------------------------------------------------------}

-- | Errors thrown by 'createHdWallet'
data CreateHdRootError =
    -- | We already have a wallet with the specified ID
    CreateHdRootExists HdRootId
  | CreateHdRootDefaultAddressDerivationFailed

-- | Errors thrown by 'createHdAccount'
data CreateHdAccountError =
    -- | The specified wallet could not be found
    CreateHdAccountUnknownRoot UnknownHdRoot

    -- | Account already exists
  | CreateHdAccountExists HdAccountId

-- | Errors thrown by 'createHdAddress'
data CreateHdAddressError =
    -- | Account not found
    CreateHdAddressUnknown UnknownHdAccount

    -- | Address already used
  | CreateHdAddressExists HdAddressId
  deriving Eq

deriveSafeCopy 1 'base ''CreateHdRootError
deriveSafeCopy 1 'base ''CreateHdAccountError
deriveSafeCopy 1 'base ''CreateHdAddressError

{-------------------------------------------------------------------------------
  CREATE
-------------------------------------------------------------------------------}

-- | Create a new wallet.
createHdRoot :: HdRoot -> Update' CreateHdRootError HdWallets ()
createHdRoot hdRoot = do
    zoom hdWalletsRoots $ do
      exists <- gets $ IxSet.member rootId
      when exists $ throwError $ CreateHdRootExists rootId
      at rootId .= Just hdRoot
  where
    rootId = hdRoot ^. hdRootId

-- | Create a new account
createHdAccount :: HdAccount -> Update' CreateHdAccountError HdWallets ()
createHdAccount hdAccount = do
    -- Check that the root ID exists
    zoomHdRootId CreateHdAccountUnknownRoot rootId $
      return ()

    zoom hdWalletsAccounts $ do
      exists <- gets $ IxSet.member accountId
      when exists $ throwError $ CreateHdAccountExists accountId
      at accountId .= Just hdAccount
  where
    accountId = hdAccount ^. hdAccountId
    rootId    = accountId ^. hdAccountIdParent

-- | Create a new address
createHdAddress :: HdAddress -> Update' CreateHdAddressError HdWallets ()
createHdAddress hdAddress = do
    -- Check that the account ID exists
    currentPkCounter <-
        zoomHdAccountId CreateHdAddressUnknown (addrId ^. hdAddressIdParent) $ do
            acc <- get
            return (acc ^. hdAccountAutoPkCounter)

    -- Create the new address
    zoom hdWalletsAddresses $ do
      exists <- gets $ IxSet.member addrId
      when exists $ throwError $ CreateHdAddressExists addrId
      at addrId .= Just (Indexed currentPkCounter hdAddress)

    -- Finally, persist the index inside the account. Don't do this earlier
    -- as the creation could still fail, and only here we are sure it will
    -- succeed.
    zoomHdAccountId CreateHdAddressUnknown (addrId ^. hdAddressIdParent) $ do
        modify (hdAccountAutoPkCounter +~ 1)

  where
    addrId = hdAddress ^. hdAddressId

{-------------------------------------------------------------------------------
  Initial values
-------------------------------------------------------------------------------}

-- | New wallet
--
-- The encrypted secret key of the wallet is assumed to be stored elsewhere in
-- some kind of secure key storage; here we ask for the hash of the public key
-- only (i.e., a 'HdRootId'). It is the responsibility of the caller to use the
-- 'BackupPhrase' and (optionally) the 'SpendingPassword' to create a new key
-- add it to the key storage. This is important, because these are secret
-- bits of information that should never end up in the DB log.
initHdRoot :: HdRootId
           -> WalletName
           -> HasSpendingPassword
           -> AssuranceLevel
           -> InDb Core.Timestamp
           -> HdRoot
initHdRoot rootId name hasPass assurance created = HdRoot {
      _hdRootId          = rootId
    , _hdRootName        = name
    , _hdRootHasPassword = hasPass
    , _hdRootAssurance   = assurance
    , _hdRootCreatedAt   = created
    }

-- | New account
--
-- It is the responsibility of the caller to check the wallet's spending
-- password.
initHdAccount :: HdAccountBase
              -> HdAccountState
              -> HdAccount
initHdAccount accountBase st = HdAccount {
      _hdAccountBase  = accountBase
    , _hdAccountName  = defName
    , _hdAccountState = st
    , _hdAccountAutoPkCounter = AutoIncrementKey 0
    }
  where
    defName = AccountName $ sformat ("Account: " % build) (accId ^. hdAccountIdIx)
    accId   = accountBase ^. hdAccountBaseId

{-------------------------------------------------------------------------------
  Pretty printing
-------------------------------------------------------------------------------}

instance Buildable CreateHdRootError where
    build (CreateHdRootExists rootId)
        = bprint ("CreateHdRootError::CreateHdRootExists "%build) rootId
    build CreateHdRootDefaultAddressDerivationFailed
        = bprint "CreateHdRootError::CreateHdRootDefaultAddressDerivationFailed"

instance Buildable CreateHdAccountError where
    build (CreateHdAccountUnknownRoot (UnknownHdRoot rootId))
        = bprint ("CreateHdAccountError::CreateHdAccountUnknownRoot "%build) rootId
    build (CreateHdAccountExists accountId)
        = bprint ("CreateHdAccountError::CreateHdAccountExists "%build) accountId

instance Buildable CreateHdAddressError where
  build (CreateHdAddressUnknown unknownRoot)
      = bprint ("CreateHdAddressUnknown: "%build) unknownRoot
  build (CreateHdAddressExists addressId)
      = bprint ("CreateHdAddressExists: "%build) addressId
