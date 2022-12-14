module Bcc.Wallet.API.V1.Transactions where

import           Bcc.Wallet.API.Request
import           Bcc.Wallet.API.Response
import           Bcc.Wallet.API.Types
import           Bcc.Wallet.API.V1.Parameters
import           Bcc.Wallet.API.V1.Types

import           Servant

type API = Tag "Transactions" 'NoTagDescription :>
    (    "transactions" :> Summary "Generate a new transaction from the source to one or multiple target addresses."
                        :> ReqBody '[ValidJSON] Payment
                        :> Post '[ValidJSON] (APIResponse Transaction)
    :<|> "transactions" :> Summary "Return the transaction history, i.e the list of all the past transactions."
                        :> QueryParam "wallet_id" WalletId
                        :> QueryParam "account_index" AccountIndex
                        :> QueryParam "address" (WalAddress)
                        :> WalletRequestParams
                        :> FilterBy '[ WalletTxId
                                     , WalletTimestamp
                                     ] Transaction
                        :> SortBy   '[ WalletTimestamp
                                     ] Transaction
                        :> Get '[ValidJSON] (APIResponse [Transaction])
    :<|> "transactions" :> "fees"
                        :> Summary "Estimate the fees which would originate from the payment."
                        :> ReqBody '[ValidJSON] Payment
                        :> Post '[ValidJSON] (APIResponse EstimatedFees)
    :<|> "transactions" :> "certificates"
                        :> Summary "Redeem a certificate"
                        :> ReqBody '[ValidJSON] Redemption
                        :> Post '[ValidJSON] (APIResponse Transaction)

    :<|> "transactions" :> "unsigned"
                        :> Summary "Create a new unsigned transaction."
                        :> ReqBody '[ValidJSON] Payment
                        :> Post '[ValidJSON] (APIResponse UnsignedTransaction)

    :<|> "transactions" :> "externally-signed"
                        :> Summary "Publish an externally-signed transaction."
                        :> ReqBody '[ValidJSON] SignedTransaction
                        :> Post '[ValidJSON] (APIResponse Transaction)
    )
