{-# LANGUAGE LambdaCase     #-}
{-# LANGUAGE NamedFieldPuns #-}

{- | A collection of plugins used by this edge node.
     A @Plugin@ is essentially a set of actions which will be run in
     a particular monad, at some point in time.
-}

-- Orphan instance for Buildable Servant.NoContent
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Bcc.Wallet.Server.Plugins
    ( Plugin
    , apiServer
    , docServer
    , acidStateSnapshots
    , setupNodeClient
    , nodeAPIServer
    ) where

import           Universum

import           Control.Retry (RetryPolicyM, RetryStatus, fullJitterBackoff,
                     limitRetries)
import qualified Control.Retry
import           Data.Acid (AcidState)
import           Data.Aeson (encode)
import qualified Data.ByteString.Char8 as BS8
import qualified Data.Text as T
import           Data.Typeable (typeOf)
import           Formatting.Buildable (build)
import           Network.HTTP.Types.Status (badRequest400)
import           Network.Wai (Application, Middleware, Response, responseLBS)
import           Network.Wai.Handler.Warp (setOnException,
                     setOnExceptionResponse)
import qualified Network.Wai.Handler.Warp as Warp
import qualified Pos.Chain.Genesis as Genesis
import           Pos.Chain.Update (updateConfiguration)
import           Pos.Client.CLI (NodeApiArgs (..))
import qualified Servant
import           Servant.Client (Scheme (..))
import qualified Servant.Client as Servant

import           Bcc.Node.API (launchNodeServer)
import           Bcc.Node.Client (NodeHttpClient)
import qualified Bcc.Node.Client as NodeClient
import qualified Bcc.Node.Manager as NodeManager
import           Bcc.NodeIPC (startNodeJsIPC)
import           Bcc.Wallet.API as API
import           Bcc.Wallet.API.V1.Headers (applicationJson)
import           Bcc.Wallet.API.V1.ReifyWalletError
                     (translateWalletLayerErrors)
import qualified Bcc.Wallet.API.V1.Types as V1
import           Bcc.Wallet.Kernel (DatabaseMode (..), PassiveWallet)
import qualified Bcc.Wallet.Kernel.Diffusion as Kernel
import qualified Bcc.Wallet.Kernel.Mode as Kernel
import qualified Bcc.Wallet.Server as Server
import           Bcc.Wallet.Server.CLI (WalletBackendParams (..),
                     WalletBackendParams (..), walletAcidInterval,
                     walletDbOptions)
import           Bcc.Wallet.Server.Middlewares (withMiddlewares)
import           Bcc.Wallet.Server.Plugins.AcidState
                     (createAndArchiveCheckpoints)
import           Bcc.Wallet.WalletLayer (ActiveWalletLayer,
                     PassiveWalletLayer)
import qualified Bcc.Wallet.WalletLayer.Kernel as WalletLayer.Kernel
import           Ntp.Client (NtpConfiguration)
import           Pos.Launcher.Resource (NodeResources (..))

import           Pos.Infra.Diffusion.Types (Diffusion (..), hoistDiffusion)
import           Pos.Infra.Shutdown (HasShutdownContext (shutdownContext),
                     ShutdownContext)
import           Pos.Launcher.Configuration (HasConfigurations)
import           Pos.Util.CompileInfo (HasCompileInfo, compileInfo,
                     withCompileInfo)
import           Pos.Util.Wlog (logError, logInfo, modifyLoggerName,
                     usingLoggerName)
import           Pos.Web (TlsParams (..), serveDocImpl, serveImpl)


-- A @Plugin@ running in the monad @m@.
type Plugin m = Diffusion m -> m ()

-- | Override defautl Warp settings to avoid printing exception to console.
-- They're already printing to logfile!
defaultSettings :: Warp.Settings
defaultSettings = Warp.defaultSettings
    & setOnException (\_ _ -> return ())

-- | A @Plugin@ to start the wallet REST server
apiServer
    :: WalletBackendParams
    -> NodeHttpClient
    -> (PassiveWalletLayer IO, PassiveWallet)
    -> [Middleware]
    -> Plugin Kernel.WalletMode
apiServer
    WalletBackendParams{..}
    nodeClient
    (passiveLayer, passiveWallet)
    middlewares
    diffusion
  = do
    env <- ask
    let diffusion' = Kernel.fromDiffusion (lower env) diffusion
    logInfo "Testing node client connection"
    eresp <- liftIO . retrying . runExceptT $ NodeClient.getNodeSettings nodeClient
    case eresp of
        Left err -> do
            logError
            $ "There was an error connecting to the node: "
            <> show err
        Right _ -> do
            logInfo "The node responded successfully."
    WalletLayer.Kernel.bracketActiveWallet passiveLayer passiveWallet diffusion' $ \active _ -> do
        ctx <- view shutdownContext
        serveImpl
            (getApplication active)
            (BS8.unpack ip)
            port
            (Just walletTLSParams)
            (Just $ setOnExceptionResponse exceptionHandler defaultSettings)
            (Just $ portCallback ctx)
  where
    (ip, port) = walletAddress

    exceptionHandler :: SomeException -> Response
    exceptionHandler se = case translateWalletLayerErrors se of
            Just we -> handleLayerError we
            Nothing -> handleGenericError se

    -- Handle domain-specific errors coming from the Wallet Layer
    handleLayerError :: V1.WalletError -> Response
    handleLayerError we =
            responseLBS (V1.toHttpErrorStatus we) [applicationJson] . encode $ we

    -- Handle general exceptions
    handleGenericError :: SomeException -> Response
    handleGenericError (SomeException se) =
        responseLBS badRequest400 [applicationJson] $ encode defWalletError
        where
            -- NOTE: to ensure that we don't leak any sensitive information,
            --       we only reveal the exception type here.
            defWalletError = V1.UnknownError $ T.pack . show $ typeOf se

    getApplication
        :: ActiveWalletLayer IO
        -> Kernel.WalletMode Application
    getApplication active = do
        logInfo "New wallet API has STARTED!"
        return
            $ withMiddlewares middlewares
            $ Servant.serve API.walletAPI
            $ Server.walletServer nodeClient active

    lower :: env -> ReaderT env IO a -> IO a
    lower env m = runReaderT m env

    portCallback :: ShutdownContext -> Word16 -> IO ()
    portCallback ctx =
        usingLoggerName "NodeIPC" . flip runReaderT ctx . startNodeJsIPC

    retrying :: MonadIO m => m (Either e a) -> m (Either e a)
    retrying a = Control.Retry.retrying policy shouldRetry (const a)
      where
        -- See <https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter>
        policy :: MonadIO m => RetryPolicyM m
        policy = fullJitterBackoff 1000000 <> limitRetries 4

        shouldRetry :: MonadIO m => RetryStatus -> Either e a -> m Bool
        shouldRetry _ (Right _) = return False
        shouldRetry _ (Left  _) = return True

-- | A @Plugin@ to serve the wallet documentation
docServer
    :: (HasConfigurations, HasCompileInfo)
    => WalletBackendParams
    -> Maybe (Plugin Kernel.WalletMode)
docServer WalletBackendParams{walletDocAddress = Nothing} = Nothing
docServer WalletBackendParams{walletDocAddress = Just (ip, port), walletTLSParams} = Just (const $ makeWalletServer)
  where
    makeWalletServer = serveDocImpl
        application
        (BS8.unpack ip)
        port
        (Just walletTLSParams)
        (Just defaultSettings)
        Nothing

    application :: Kernel.WalletMode Application
    application =
        return $ Servant.serve API.walletDoc Server.walletDocServer

-- | A @Plugin@ to periodically compact & snapshot the acid-state database.
acidStateSnapshots :: AcidState db
                   -> WalletBackendParams
                   -> DatabaseMode
                   -> Plugin Kernel.WalletMode
acidStateSnapshots dbRef params dbMode = const worker
  where
    worker = do
      let opts = walletDbOptions params
      modifyLoggerName (const "acid-state-checkpoint-plugin") $
          createAndArchiveCheckpoints
              dbRef
              (walletAcidInterval opts)
              dbMode

instance Buildable Servant.NoContent where
    build Servant.NoContent = build ()

nodeAPIServer
    :: HasConfigurations
    => WalletBackendParams
    -> Genesis.Config
    -> NtpConfiguration
    -> NodeResources ()
    -> Plugin Kernel.WalletMode
nodeAPIServer params genConfig ntpConfig nodeResources diffusion = withCompileInfo $ do
    env <- ask
    lift $??launchNodeServer
        apiArgs
        ntpConfig
        nodeResources
        updateConfiguration
        compileInfo
        genConfig
        (hoistDiffusion (flip runReaderT env) lift diffusion)
  where
    apiArgs = NodeApiArgs
        (walletNodeAddress params)
        (Just $ walletTLSParams params) -- NOTE Using the same certs for both wallet server and node server
        False -- debug mode
        (walletNodeDocAddress params)

setupNodeClient
    :: MonadIO m
    => (String, Int)
    -> TlsParams
    -> m NodeHttpClient
setupNodeClient (serverHost, serverPort) params = liftIO $ do
    let serverId = (serverHost, BS8.pack $ show serverPort)
    caChain <- NodeManager.readSignedObject (tpCaPath params)
    clientCredentials <- NodeManager.credentialLoadX509 (tpCertPath params) (tpKeyPath params) >>= \case
        Right   a -> return a
        Left  err -> fail $ "Error decoding X509 certificates: " <> err
    manager <- NodeManager.newManager $ NodeManager.mkHttpsManagerSettings serverId caChain clientCredentials

    let
        baseUrl = Servant.BaseUrl Https serverHost serverPort mempty
        walletClient :: NodeHttpClient
        walletClient = NodeClient.mkHttpClient baseUrl manager

    return walletClient
