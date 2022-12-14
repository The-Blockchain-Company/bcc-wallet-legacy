{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE TypeApplications    #-}

module Test.Spec.Kernel (
    spec
  ) where

import           Universum

import qualified Data.Set as Set
import           Test.Hspec (SpecWith)

import qualified Bcc.Wallet.Kernel as Kernel
import           Bcc.Wallet.Kernel.DB.BlockMeta (BlockMeta)
import qualified Bcc.Wallet.Kernel.Diffusion as Kernel
import qualified Bcc.Wallet.Kernel.Keystore as Keystore
import           Bcc.Wallet.Kernel.NodeStateAdaptor (mockNodeStateDef)
import qualified Bcc.Wallet.Kernel.Read as Kernel

import           Pos.Chain.Genesis (Config (..))
import           Pos.Core (Coeff (..), TxSizeLinear (..))
import           Pos.Core.Chrono
import           Pos.Crypto (ProtocolMagic (..), RequiresNetworkMagic (..))
import           Pos.Infra.InjectFail (mkFInjects)

import           Data.Validated
import           Test.Infrastructure.Generator
import           Test.Infrastructure.Genesis
import           Test.Pos.Configuration (withProvidedMagicConfig)
import           Test.QuickCheck (withMaxSuccess)
import           Test.Spec.BlockMetaScenarios
import           Test.Spec.TxMetaScenarios
import           Util.Buildable.Hspec
import           Util.Buildable.QuickCheck
import           UTxO.Bootstrap
import           UTxO.Context
import           UTxO.Crypto
import           UTxO.DSL
import           UTxO.ToCardano.Interpreter (BlockMeta' (..), DSL2Cardano,
                     IntCtxt, IntException, Interpret, int, runIntT')
import           UTxO.Translate
import           Wallet.Abstract
import           Wallet.Inductive
import           Wallet.Inductive.Bcc
import           Wallet.Inductive.ExtWalletEvent (UseWalletWorker (..))
import           Wallet.Inductive.Validation

import qualified Wallet.Rollback.Full as Full

{-------------------------------------------------------------------------------
  Compare the wallet kernel with the pure model
-------------------------------------------------------------------------------}

withWithoutWW :: (UseWalletWorker -> SpecWith a) -> SpecWith a
withWithoutWW specWith = do
    describe "without walletworker" $ specWith DontUseWalletWorker
    describe "with walletworker"    $ specWith UseWalletWorker

spec :: Spec
spec = do
    runWithMagic RequiresNoMagic
    runWithMagic RequiresMagic

runWithMagic :: RequiresNetworkMagic -> Spec
runWithMagic rnm = do
    pm <- (\ident -> ProtocolMagic ident rnm) <$> runIO (generate arbitrary)
    describe ("(requiresNetworkMagic=" ++ show rnm ++ ")") $
        specBody pm

specBody :: ProtocolMagic -> Spec
specBody pm = do
    describe "test TxMeta insertion" $ do
      withWithoutWW $ \useWW -> do
        it "TxMetaScenarioA" $ bracketTxMeta useWW (txMetaScenarioA genesis)
        it "TxMetaScenarioB" $ bracketTxMeta useWW (txMetaScenarioB genesis)
        it "TxMetaScenarioC" $ bracketTxMeta useWW (txMetaScenarioC genesis)
        it "TxMetaScenarioD" $ bracketTxMeta useWW (txMetaScenarioD genesis)
        it "TxMetaScenarioE" $ bracketTxMeta useWW (txMetaScenarioE genesis)
        it "TxMetaScenarioF" $ bracketTxMeta useWW (txMetaScenarioF genesis)
        it "TxMetaScenarioG" $ bracketTxMeta useWW (txMetaScenarioG genesis)
        it "TxMetaScenarioH" $ bracketTxMeta useWW (txMetaScenarioH genesis)
        it "TxMetaScenarioI" $ bracketTxMeta useWW (txMetaScenarioI genesis)
        it "TxMetaScenarioJ" $ bracketTxMeta useWW (txMetaScenarioJ genesis)

    describe "Compare wallet kernel to pure model" $ do
      describe "Using hand-written inductive wallets, computes the expected block metadata for" $ do
        withWithoutWW $ \useWW -> do
          it "...blockMetaScenarioA" $ bracketActiveWallet pm $ checkBlockMeta' useWW (blockMetaScenarioA genesis)
          it "...blockMetaScenarioB" $ bracketActiveWallet pm $ checkBlockMeta' useWW (blockMetaScenarioB genesis)
          it "...blockMetaScenarioC" $ bracketActiveWallet pm $ checkBlockMeta' useWW (blockMetaScenarioC genesis)
          it "...blockMetaScenarioD" $ bracketActiveWallet pm $ checkBlockMeta' useWW (blockMetaScenarioD genesis)
          it "...blockMetaScenarioE" $ bracketActiveWallet pm $ checkBlockMeta' useWW (blockMetaScenarioE genesis)
          it "...blockMetaScenarioF" $ bracketActiveWallet pm $ checkBlockMeta' useWW (blockMetaScenarioF genesis)
          it "...blockMetaScenarioG" $ bracketActiveWallet pm $ checkBlockMeta' useWW (blockMetaScenarioG genesis)
          it "...blockMetaScenarioH" $ bracketActiveWallet pm $ checkBlockMeta' useWW (blockMetaScenarioH genesis)

      describe "Using hand-written inductive wallets" $ do
        withWithoutWW $ \useWW ->
          it "computes identical results in presence of dependent pending transactions" $
            bracketActiveWallet pm $ \activeWallet -> do
              checkEquivalent useWW activeWallet (dependentPending genesis)

      withWithoutWW $ \useWW ->
        it "computes identical results using generated inductive wallets" $
          withMaxSuccess 5 $ forAll (genInductiveUsingModel model) $ \ind -> do
            conjoin [
                shouldBeValidated $ void (inductiveIsValid ind)
              , bracketActiveWallet pm $ \activeWallet -> do
                  checkEquivalent useWW activeWallet ind
              ]

  where
    transCtxt = runTranslateNoErrors pm ask
    boot      = bootstrapTransaction transCtxt

    ourActorIx   = 0
    model        = (cardanoModel linearFeePolicy ourActorIx (transCtxtAddrs transCtxt) boot)

    -- TODO: These constants should not be hardcoded here.
    linearFeePolicy :: TxSizeLinear
    linearFeePolicy = TxSizeLinear (Coeff 155381) (Coeff 43.946)

    genesis :: GenesisValues GivenHash Addr
    genesis = genesisValues linearFeePolicy boot

    checkEquivalent :: forall h. Hash h Addr
                    => UseWalletWorker
                    -> Kernel.ActiveWallet
                    -> Inductive h Addr
                    -> Expectation
    checkEquivalent useWW w ind = shouldReturnValidated $ evaluate useWW w ind

    -- | Evaluate the inductive wallet step by step and compare the DSL and Bcc results
    --   at the end of each step.
    -- NOTE: This evaluation changes the state of the wallet and also produces an
    -- interpretation context, which we return to enable further custom interpretation
    evaluate :: forall h. Hash h Addr
             => UseWalletWorker
             -> Kernel.ActiveWallet
             -> Inductive h Addr
             -> IO (Validated EquivalenceViolation (IntCtxt h))
    evaluate useWW activeWallet ind = do
       fmap (fmap snd) $ runTranslateTNoErrors pm $ do
         equivalentT useWW activeWallet esk (mkWallet ours') ind
      where
        esk = deriveRootEsk (IxPoor ourActorIx)
        -- all addresses belonging to this poor actor
        ours' a = a `Set.member` (inductiveOurs ind)

        -- | Derive ESK from the poor actor by resolving the actor's first HD address
        deriveRootEsk actorIx = encKpEnc ekp
            where
              addrIx       = 0 -- we can assume that the first HD address of the Poor actor exists
              AddrInfo{..} = resolveAddr (Addr actorIx addrIx) transCtxt
              Just ekp     = addrInfoMasterKey

    evaluate' :: forall h. Hash h Addr
             => UseWalletWorker
             -> Kernel.ActiveWallet
             -> Inductive h Addr
             -> IO (IntCtxt h)
    evaluate' useWW activeWallet ind = do
        res <- evaluate useWW activeWallet ind
        case res of
            Invalid _ e    -> throwM e
            Valid intCtxt' -> return intCtxt'

    mkWallet :: Hash h Addr => Ours Addr -> Transaction h Addr -> Wallet h Addr
    mkWallet = walletBoot Full.walletEmpty

    -- | Translates the DSL BlockMeta' value to BlockMeta
    intBlockMeta :: forall h. (Interpret DSL2Cardano h (BlockMeta' h))
                 => IntCtxt h
                 -> (BlockMeta' h)
                 -> TranslateT IntException IO BlockMeta
    intBlockMeta intCtxt a = do
        ma' <- catchTranslateErrors $ runIntT' intCtxt $ (int @DSL2Cardano) a
        case ma' of
          Left err         -> liftIO $ throwM err
          Right (a', _ic') -> return a'

    checkBlockMeta' :: Hash h Addr
                    => UseWalletWorker
                    -> (Inductive h Addr, BlockMeta' h)
                    -> Kernel.ActiveWallet
                    -> IO ()
    checkBlockMeta' useWW (ind, blockMeta') activeWallet
        = do
            -- the evaluation changes the wallet state; we also capture the interpretation context
            intCtxt <- evaluate' useWW activeWallet ind

            -- translate DSL BlockMeta' to Bcc BlockMeta
            expected' <- runTranslateT pm $ intBlockMeta intCtxt blockMeta'

            -- grab a snapshot of the wallet state to get the BlockMeta produced by evaluating the inductive
            snapshot <- liftIO (Kernel.getWalletSnapshot (Kernel.walletPassive activeWallet))
            let actual' = actualBlockMeta snapshot

            shouldBe actual' expected'

    bracketTxMeta :: Hash h Addr
                  => UseWalletWorker
                  -> TxScenarioRet h
                  -> IO ()
    bracketTxMeta useWW (nodeState, ind, check) =
      bracketActiveWalletTxMeta pm nodeState bracketAction
        where
          bracketAction activeWallet = do
            _ <- evaluate' useWW activeWallet ind
            check $ Kernel.walletPassive $ activeWallet






{-------------------------------------------------------------------------------
  Manually written inductives

  NOTE: In order to test the wallet we want a HD structure. This means that
  the rich actors are not suitable test subjects.
-------------------------------------------------------------------------------}

-- | Inductive where the rollback causes dependent transactions to exist
--
-- This tests that when we report the 'change' of the wallet, we don't include
-- any outputs from pending transactions that are consumed by /other/ pending
-- transactions.
dependentPending :: forall h. Hash h Addr
                 => GenesisValues h Addr -> Inductive h Addr
dependentPending GenesisValues{..} = Inductive {
      inductiveBoot   = boot
    , inductiveOurs   = Set.singleton p0
    , inductiveEvents = OldestFirst [
          NewPending t0                  -- t0 pending
        , ApplyBlock $ OldestFirst [t0]  -- t0 new confirmed, change available
        , NewPending t1                  -- t1 pending, uses change from t0
        , Rollback                       -- now we have a dependent pending tr
        ]
    }
  where
    fee = overestimate txFee 1 2

    t0 :: Transaction h Addr
    t0 = Transaction {
             trFresh = 0
           , trIns   = Set.fromList [ fst initUtxoP0 ]
           , trOuts  = [ Output p1 1000
                       , Output p0 (initBalP0 - 1 * (1000 + fee))
                       ]
           , trFee   = fee
           , trHash  = 1
           , trExtra = []
           }

    t1 :: Transaction h Addr
    t1 = Transaction {
             trFresh = 0
           , trIns   = Set.fromList [ Input (hash t0) 1 ]
           , trOuts  = [ Output p1 1000
                       , Output p0 (initBalP0 - 2 * (1000 + fee))
                       ]
           , trFee   = fee
           , trHash  = 2
           , trExtra = []
           }

{-------------------------------------------------------------------------------
  Wallet resource management
-------------------------------------------------------------------------------}

-- | Initialize passive wallet in a manner suitable for the unit tests
bracketPassiveWallet :: ProtocolMagic -> (Kernel.PassiveWallet -> IO a) -> IO a
bracketPassiveWallet pm postHook = do
    Keystore.bracketTestKeystore $ \keystore -> do
        mockFInjects <- mkFInjects mempty
        Kernel.bracketPassiveWallet
            pm
            Kernel.UseInMemory
            logMessage
            keystore
            mockNodeStateDef
            mockFInjects
            postHook
  where
   -- TODO: Decide what to do with logging.
   -- For now we are not logging them to stdout to not alter the output of
   -- the test runner, but in the future we could store them into a mutable
   -- reference or a TBQueue and perform assertions on them.
    logMessage _ _  = return ()

-- | Initialize active wallet in a manner suitable for generator-based testing
bracketActiveWallet :: ProtocolMagic -> (Kernel.ActiveWallet -> IO a) -> IO a
bracketActiveWallet pm test = withProvidedMagicConfig pm $ \genesisConfig _ _ -> do
    bracketPassiveWallet (configProtocolMagic genesisConfig) $ \passive ->
        Kernel.bracketActiveWallet passive
                                   diffusion
                                   test

-- TODO: Decide what we want to do with submitted transactions
diffusion :: Kernel.WalletDiffusion
diffusion =  Kernel.WalletDiffusion {
      walletSendTx                = \_tx -> return False
    , walletGetSubscriptionStatus = return mempty
    }
