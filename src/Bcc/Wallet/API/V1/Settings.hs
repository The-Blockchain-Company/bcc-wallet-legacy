module Bcc.Wallet.API.V1.Settings where

import           Bcc.Wallet.API.Response (APIResponse, ValidJSON)
import           Bcc.Wallet.API.Types
import           Bcc.Wallet.API.V1.Types

import           Servant

type API = Tag "Settings" 'NoTagDescription :>
         ( "node-settings"  :> Summary "Retrieves the static settings for this node."
                            :> Get '[ValidJSON] (APIResponse NodeSettings)
         )
