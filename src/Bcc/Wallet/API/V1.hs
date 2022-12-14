module Bcc.Wallet.API.V1 where


import           Servant ((:<|>))

import qualified Bcc.Wallet.API.V1.Accounts as Accounts
import qualified Bcc.Wallet.API.V1.Addresses as Addresses
import qualified Bcc.Wallet.API.V1.Transactions as Transactions
import qualified Bcc.Wallet.API.V1.Wallets as Wallets

import qualified Pos.Node.API as Node

type API =  Addresses.API
       :<|> Wallets.FullyOwnedAPI
       :<|> Wallets.ExternallyOwnedAPI
       :<|> Accounts.API
       :<|> Transactions.API
       :<|> Node.SettingsAPI
       :<|> Node.InfoAPI
