module Bcc.Wallet.API.V1.Handlers.Info (handlers) where

import           Universum

import           Servant

import qualified Bcc.Node.Client as NodeClient
import           Bcc.Wallet.API.Response (APIResponse, single)
import qualified Bcc.Wallet.API.V1.Info as Info
import           Bcc.Wallet.API.V1.Types (ForceNtpCheck, NodeInfo)
import           Bcc.Wallet.NodeProxy (NodeHttpClient, handleNodeError)

handlers :: NodeHttpClient -> ServerT Info.API Handler
handlers = getNodeInfo

getNodeInfo
    :: NodeHttpClient
    -> ForceNtpCheck
    -> Handler (APIResponse NodeInfo)
getNodeInfo nc forceNtp = do
    eni <- liftIO . runExceptT $ NodeClient.getNodeInfo nc forceNtp
    case eni of
        Left err  ->
            handleNodeError err
        Right nodeInfo ->
            single <$> pure nodeInfo
