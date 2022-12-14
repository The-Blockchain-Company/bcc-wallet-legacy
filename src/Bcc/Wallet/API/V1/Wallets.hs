module Bcc.Wallet.API.V1.Wallets where

import           Bcc.Wallet.API.Request
import           Bcc.Wallet.API.Response
import           Bcc.Wallet.API.Types
import           Bcc.Wallet.API.V1.Parameters
import           Bcc.Wallet.API.V1.Types
import           Pos.Core as Core

import           Servant

type FullyOwnedAPI = Tag "Wallets" 'NoTagDescription :>
    (    "wallets" :> Summary "Create a new Wallet or restore an existing one."
                   :> ReqBody '[ValidJSON] (New Wallet)
                   :> PostCreated '[ValidJSON] (APIResponse Wallet)
    :<|> "wallets" :> Summary "Return a list of the available wallets."
                   :> WalletRequestParams
                   :> FilterBy '[ WalletId
                                , Core.Coin
                                ] Wallet
                   :> SortBy   '[ Core.Coin
                                , WalletTimestamp
                                ] Wallet
                   :> Get '[ValidJSON] (APIResponse [Wallet])
    :<|> "wallets" :> CaptureWalletId
                   :> "password"
                   :> Summary "Update the password for the given Wallet."
                   :> ReqBody '[ValidJSON] PasswordUpdate
                   :> Put '[ValidJSON] (APIResponse Wallet)
    :<|> "wallets" :> CaptureWalletId
                   :> Summary "Delete the given Wallet and all its accounts."
                   :> DeleteNoContent '[ValidJSON] NoContent
    :<|> "wallets" :> CaptureWalletId
                   :> Summary "Return the Wallet identified by the given walletId."
                   :> Get '[ValidJSON] (APIResponse Wallet)
    :<|> "wallets" :> CaptureWalletId
                   :> Summary "Update the Wallet identified by the given walletId."
                   :> ReqBody '[ValidJSON] (Update Wallet)
                   :> Put '[ValidJSON] (APIResponse Wallet)
    :<|> "wallets" :> CaptureWalletId :> "statistics" :> "utxos"
                   :> Summary "Return UTxO statistics for the Wallet identified by the given walletId."
                   :> Get '[ValidJSON] (APIResponse UtxoStatistics)
    )

type ExternallyOwnedAPI = Tag "Externally Owned Wallets" 'NoTagDescription
    :> ( "externally-owned-wallets"
        :> Summary "Create a new Wallet or restore an existing one."
        :> ReqBody '[ValidJSON] (NewEosWallet)
        :> PostCreated '[ValidJSON] (APIResponse EosWallet)

    :<|> "externally-owned-wallets"
        :> Summary "Return the Wallet identified by the given walletId."
        :> CaptureWalletId
        :> Get '[ValidJSON] (APIResponse EosWallet)

    :<|> "externally-owned-wallets"
        :> Summary "Update the Wallet identified by the given walletId."
        :> CaptureWalletId
        :> ReqBody '[ValidJSON] (UpdateEosWallet)
        :> Put '[ValidJSON] (APIResponse EosWallet)

    :<|> "externally-owned-wallets"
        :> Summary "Delete the given Wallet and all its accounts."
        :> CaptureWalletId
        :> DeleteNoContent '[ValidJSON] NoContent

    :<|> "externally-owned-wallets"
        :> Summary "Return a list of the available wallets."
        :> WalletRequestParams
        :> FilterBy
           '[ WalletId
            , Core.Coin
            ] EosWallet
        :> SortBy
           '[ Core.Coin
            , WalletTimestamp
            ] EosWallet
        :> Get '[ValidJSON] (APIResponse [EosWallet])

    )
