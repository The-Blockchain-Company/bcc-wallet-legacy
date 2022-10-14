module Bcc.Wallet.API.Internal.Handlers (handlers) where

import           Universum

import           Servant ((:<|>) (..), Handler, NoContent (..), ServerT)

import           Bcc.Node.Client (NodeHttpClient)
import qualified Bcc.Node.Client as NodeClient
import qualified Pos.Node.API as NodeClient

import qualified Bcc.Wallet.API.Internal as Internal
import           Bcc.Wallet.API.Response (APIResponse, single)
import           Bcc.Wallet.API.V1.Types (Wallet, WalletImport,
                     WalletSoftwareVersion (..))
import           Bcc.Wallet.NodeProxy (handleNodeError)
import           Bcc.Wallet.WalletLayer (PassiveWalletLayer)
import qualified Bcc.Wallet.WalletLayer as WalletLayer

handlers
    :: NodeHttpClient
    -> PassiveWalletLayer IO
    -> ServerT Internal.API Handler
handlers nc w =
    nextUpdate nc
    :<|> applyUpdate nc
    :<|> postponeUpdate
    :<|> resetWalletState w
    :<|> importWallet w

nextUpdate :: NodeHttpClient -> Handler (APIResponse WalletSoftwareVersion)
nextUpdate nc = do
    emUpd <- liftIO . runExceptT $ NodeClient.getNextUpdate nc
    case emUpd of
        Left err  ->
            handleNodeError err
        Right (NodeClient.V1 upd) ->
            single <$> pure (WalletSoftwareVersion upd)

applyUpdate :: NodeHttpClient -> Handler NoContent
applyUpdate nc = do
    enc <- liftIO . runExceptT $ NodeClient.restartNode nc
    case enc of
        Left err ->
            handleNodeError err
        Right () ->
            pure NoContent

-- | This endpoint has been made into a no-op.
postponeUpdate :: Handler NoContent
postponeUpdate = pure NoContent

resetWalletState :: PassiveWalletLayer IO -> Handler NoContent
resetWalletState w =
    liftIO (WalletLayer.resetWalletState w) >> return NoContent

-- | Imports a 'Wallet' from a backup.
importWallet :: PassiveWalletLayer IO -> WalletImport -> Handler (APIResponse Wallet)
importWallet w walletImport = do
    res <- liftIO $ WalletLayer.importWallet w walletImport
    case res of
         Left e               -> throwM e
         Right importedWallet -> pure $ single importedWallet
