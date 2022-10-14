module Bcc.Wallet.API.V1.Addresses where

import           Servant
import           Universum (Text)

import           Bcc.Wallet.API.Response
import           Bcc.Wallet.API.Types
import           Bcc.Wallet.API.V1.Parameters
import           Bcc.Wallet.API.V1.Types


type API = Tag "Addresses" 'NoTagDescription :>
      (    "addresses" :> WalletRequestParams
                       :> Summary "Return a list of the addresses."
                       :> Get '[ValidJSON] (APIResponse [WalletAddress])
      :<|> "addresses" :> ReqBody '[ValidJSON] NewAddress
                       :> Summary "Create a new Address."
                       :> Post '[ValidJSON] (APIResponse WalletAddress)
      :<|> "addresses" :> Capture "address" Text
                       :> Summary "Return interesting information about an address, if available and valid."
                       :> Get '[ValidJSON] (APIResponse WalletAddress)
      :<|> "wallets" :> CaptureWalletId :> "addresses"
        :> Summary "Batch import existing addresses"
        :> ReqBody '[ValidJSON] [WalAddress]
        :> Post '[ValidJSON] (APIResponse (BatchImportResult WalAddress))
      )
