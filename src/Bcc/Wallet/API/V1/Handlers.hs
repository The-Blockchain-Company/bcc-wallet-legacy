module Bcc.Wallet.API.V1.Handlers (handlers) where

import           Servant
import           Universum

import qualified Bcc.Wallet.API.V1 as V1
import qualified Bcc.Wallet.API.V1.Handlers.Accounts as Accounts
import qualified Bcc.Wallet.API.V1.Handlers.Addresses as Addresses
import qualified Bcc.Wallet.API.V1.Handlers.Info as Info
import qualified Bcc.Wallet.API.V1.Handlers.Settings as Settings
import qualified Bcc.Wallet.API.V1.Handlers.Transactions as Transactions
import qualified Bcc.Wallet.API.V1.Handlers.Wallets as Wallets

import           Bcc.Wallet.NodeProxy (NodeHttpClient)
import           Bcc.Wallet.WalletLayer (ActiveWalletLayer,
                     walletPassiveLayer)


handlers :: NodeHttpClient -> ActiveWalletLayer IO -> Server V1.API
handlers nc aw =
    Addresses.handlers pw
    :<|> Wallets.fullyOwnedHandlers pw
    :<|> Wallets.externallyOwnedHandlers pw
    :<|> Accounts.handlers pw
    :<|> Transactions.handlers aw
    :<|> Settings.handlers nc
    :<|> Info.handlers nc
  where
    pw = walletPassiveLayer aw
