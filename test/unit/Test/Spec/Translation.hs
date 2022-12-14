{-# LANGUAGE TypeApplications #-}
module Test.Spec.Translation (
    spec
  ) where

import           Universum

import qualified Data.Set as Set
import           Formatting (bprint, build, shown, (%))
import qualified Formatting.Buildable
import           Pos.Core.Chrono
import           Pos.Crypto (ProtocolMagic (..), RequiresNetworkMagic (..))
import           Serokell.Util (mapJson)
import           Test.Hspec.QuickCheck
import           Test.QuickCheck (withMaxSuccess)

import qualified Pos.Chain.Block as Bcc
import           Pos.Chain.Txp (TxValidationRules (..))
import qualified Pos.Chain.Txp as Bcc
import           Pos.Core (Coeff (..), EpochIndex (..), TxSizeLinear (..))

import           Data.Validated
import           Test.Infrastructure.Generator
import           Test.Infrastructure.Genesis
import           Util.Buildable.Hspec
import           Util.Buildable.QuickCheck
import           UTxO.Bootstrap
import           UTxO.Context
import           UTxO.DSL
import           UTxO.IntTrans
import           UTxO.ToCardano.Interpreter
import           UTxO.Translate

{-------------------------------------------------------------------------------
  UTxO->Bcc translation tests
-------------------------------------------------------------------------------}

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
    describe "Translation sanity checks" $ do
      it "can construct and verify empty block" $
        intAndVerifyPure pm linearFeePolicy emptyBlock `shouldSatisfy` expectValid

      it "can construct and verify block with one transaction" $
        intAndVerifyPure pm linearFeePolicy oneTrans `shouldSatisfy` expectValid

      it "can construct and verify example 1 from the UTxO paper" $
        intAndVerifyPure pm linearFeePolicy example1 `shouldSatisfy` expectValid

      it "can reject overspending" $
        intAndVerifyPure pm linearFeePolicy overspend `shouldSatisfy` expectInvalid

      it "can reject double spending" $
        intAndVerifyPure pm linearFeePolicy doublespend `shouldSatisfy` expectInvalid

      -- There are subtle points near the epoch boundary, so we test from a
      -- few blocks less to a few blocks more than the length of an epoch
      prop "can construct and verify chain that spans epochs" $ withMaxSuccess 5 $
        let epochSlots = runTranslateNoErrors pm $ asks (ccEpochSlots . tcCardano)
        in forAll (choose (  1,  3) :: Gen Int) $ \numEpochs ->
           forAll (choose (-10, 10) :: Gen Int) $ \extraSlots ->
             let numSlots = numEpochs * fromIntegral epochSlots + extraSlots in
             shouldSatisfy
               (intAndVerifyPure pm linearFeePolicy (spanEpochs numSlots))
               expectValid

    describe "Translation QuickCheck tests" $ do
      prop "can translate randomly generated chains" $ withMaxSuccess 5 $
        forAll
          (intAndVerifyGen pm (genChainUsingModel . cardanoModel linearFeePolicy ourActorIx allAddrs))
          expectValid

  where
    transCtxt = runTranslateNoErrors pm ask
    allAddrs  = transCtxtAddrs transCtxt

    ourActorIx = 0

    linearFeePolicy = TxSizeLinear (Coeff 155381) (Coeff 43.946)

{-------------------------------------------------------------------------------
  Example hand-constructed chains
-------------------------------------------------------------------------------}

emptyBlock :: GenesisValues h a -> Chain h a
emptyBlock _ = OldestFirst [OldestFirst []]

oneTrans :: Hash h Addr => GenesisValues h Addr -> Chain h Addr
oneTrans GenesisValues{..} = OldestFirst [OldestFirst [t1]]
  where
    fee1 = overestimate txFee 1 2
    t1   = Transaction {
               trFresh = 0
             , trFee   = fee1
             , trHash  = 1
             , trIns   = Set.fromList [ fst initUtxoR0 ]
             , trOuts  = [ Output r1 1000
                         , Output r0 (initBalR0 - 1000 - fee1)
                         ]
             , trExtra = ["t1"]
             }

-- | Try to transfer from R0 to R1, but leaving R0's balance the same
overspend :: Hash h Addr => GenesisValues h Addr -> Chain h Addr
overspend GenesisValues{..} = OldestFirst [OldestFirst [t1]]
  where
    fee1 = overestimate txFee 1 2
    t1   = Transaction {
               trFresh = 0
             , trFee   = fee1
             , trHash  = 1
             , trIns   = Set.fromList [ fst initUtxoR0 ]
             , trOuts  = [ Output r1 1000
                         , Output r0 initBalR0
                         ]
             , trExtra = ["t1"]
             }

-- | Try to transfer to R1 and R2 using the same output
doublespend :: Hash h Addr => GenesisValues h Addr -> Chain h Addr
doublespend GenesisValues{..} = OldestFirst [OldestFirst [t1, t2]]
  where
    fee1 = overestimate txFee 1 2
    t1   = Transaction {
               trFresh = 0
             , trFee   = fee1
             , trHash  = 1
             , trIns   = Set.fromList [ fst initUtxoR0 ]
             , trOuts  = [ Output r1 1000
                         , Output r0 (initBalR0 - 1000 - fee1)
                         ]
             , trExtra = ["t1"]
             }

    fee2 = overestimate txFee 1 2
    t2   = Transaction {
               trFresh = 0
             , trFee   = fee2
             , trHash  = 2
             , trIns   = Set.fromList [ fst initUtxoR0 ]
             , trOuts  = [ Output r2 1000
                         , Output r0 (initBalR0 - 1000 - fee2)
                         ]
             , trExtra = ["t2"]
             }

-- | Translation of example 1 of the paper, adjusted to allow for fees
--
-- Transaction t1 in the example creates new coins, and transaction t2
-- tranfers this to an ordinary address. In other words, t1 and t2
-- corresponds to the bootstrap transactions.
--
-- Transaction t3 then transfers part of R0's balance to R1, returning the
-- rest to back to R0; and t4 transfers the remainder of R0's balance to
-- R2.
--
-- Transaction 5 in example 1 is a transaction /from/ the treasury /to/ an
-- ordinary address. This currently has no equivalent in Bcc, so we omit
-- it.
example1 :: Hash h Addr => GenesisValues h Addr -> Chain h Addr
example1 GenesisValues{..} = OldestFirst [OldestFirst [t3, t4]]
  where
    fee3 = overestimate txFee 1 2
    t3   = Transaction {
               trFresh = 0
             , trFee   = fee3
             , trHash  = 3
             , trIns   = Set.fromList [ fst initUtxoR0 ]
             , trOuts  = [ Output r1 1000
                         , Output r0 (initBalR0 - 1000 - fee3)
                         ]
             , trExtra = ["t3"]
             }

    fee4 = overestimate txFee 1 1
    t4   = Transaction {
               trFresh = 0
             , trFee   = fee4
             , trHash  = 4
             , trIns   = Set.fromList [ Input (hash t3) 1 ]
             , trOuts  = [ Output r2 (initBalR0 - 1000 - fee3 - fee4) ]
             , trExtra = ["t4"]
             }


-- | Chain that spans epochs
spanEpochs :: forall h. Hash h Addr
           => Int -> GenesisValues h Addr -> Chain h Addr
spanEpochs numSlots GenesisValues{..} = OldestFirst $
    go 1
       (fst initUtxoR0)
       (fst initUtxoR1)
       initBalR0
       initBalR1
       numSlots
  where
    go :: Int           -- Next available hash
       -> Input h Addr  -- UTxO entry with r0's balance
       -> Input h Addr  -- UTxO entry with r1's balance
       -> Value         -- r0's current total balance
       -> Value         -- r1's current total balance
       -> Int           -- Number of cycles to go
       -> [Block h Addr]
    go _ _ _ _ _ 1 = []
    go freshHash r0utxo r1utxo r0balance r1balance n =
        let tPing = ping freshHash       r0utxo r0balance
            tPong = pong (freshHash + 1) r1utxo r1balance
        in OldestFirst [tPing, tPong]
         : go (freshHash + 2)
              (Input (hash tPing) 1)
              (Input (hash tPong) 1)
              (r0balance - 10 - fee)
              (r1balance - 10 - fee)
              (n - 1)

    -- Rich 0 transferring a small amount to rich 1
    ping :: Int -> Input h Addr -> Value -> Transaction h Addr
    ping freshHash r0utxo r0balance = Transaction {
          trFresh = 0
        , trFee   = fee
        , trHash  = freshHash
        , trIns   = Set.fromList [ r0utxo ]
        , trOuts  = [ Output r1 10
                    , Output r0 (r0balance - 10 - fee)
                    ]
        , trExtra = ["ping"]
        }

    -- Rich 1 transferring a small amount to rich 0
    pong :: Int -> Input h Addr -> Value -> Transaction h Addr
    pong freshHash r1utxo r1balance = Transaction {
          trFresh = 0
        , trFee   = fee
        , trHash  = freshHash
        , trIns   = Set.fromList [ r1utxo ]
        , trOuts  = [ Output r0 10
                    , Output r1 (r1balance - 10 - fee)
                    ]
        , trExtra = ["pong"]
        }

    fee :: Value
    fee = overestimate txFee 1 2


{-------------------------------------------------------------------------------
  Verify chain
-------------------------------------------------------------------------------}

intAndVerifyPure :: ProtocolMagic
                 -> TxSizeLinear
                 -> (GenesisValues GivenHash Addr -> Chain GivenHash Addr)
                 -> ValidationResult GivenHash Addr
intAndVerifyPure pm txSizeLinear pc = runIdentity $
    intAndVerify pm (Identity . pc . genesisValues txSizeLinear)

-- | Specialization of 'intAndVerify' to 'Gen'
intAndVerifyGen :: ProtocolMagic -> (Transaction GivenHash Addr
                -> Gen (Chain GivenHash Addr)) -> Gen (ValidationResult GivenHash Addr)
intAndVerifyGen = intAndVerify

-- | Specialization of 'intAndVerifyChain' to 'GivenHash'
intAndVerify :: Monad m
             => ProtocolMagic
             -> (Transaction GivenHash Addr -> m (Chain GivenHash Addr))
             -> m (ValidationResult GivenHash Addr)
intAndVerify = intAndVerifyChain

-- | Interpret and verify a chain.
intAndVerifyChain :: (Hash h Addr, Monad m)
                  => ProtocolMagic
                  -> (Transaction h Addr -> m (Chain h Addr))
                  -> m (ValidationResult h Addr)
intAndVerifyChain pm pc = runTranslateT pm $ do
    boot  <- asks bootstrapTransaction
    chain <- lift $ pc boot
    let ledger      = chainToLedger boot chain
        dslIsValid  = ledgerIsValid ledger
        dslUtxo     = ledgerUtxo    ledger
    intResult <- catchTranslateErrors $ runIntBoot' boot $ int @DSL2Cardano chain
    case intResult of
      Left e ->
        case dslIsValid of
          Valid     () -> return $ Disagreement ledger (UnexpectedError e)
          Invalid _ e' -> return $ ExpectedInvalid' e' e
      Right (chain', ctxt) -> do
        let chain'' = fromMaybe (error "intAndVerify: Nothing")
                    $ nonEmptyOldestFirst
                    $ chain'
        isCardanoValid <- verifyBlocksPrefix chain'' dummyTxValRules
        case (dslIsValid, isCardanoValid) of
          (Invalid _ e' , Invalid _ e) -> return $ ExpectedInvalid e' e
          (Invalid _ e' , Valid     _) -> return $ Disagreement ledger (UnexpectedValid e')
          (Valid     () , Invalid _ e) -> return $ Disagreement ledger (UnexpectedInvalid e)
          (Valid     () , Valid (_undo, finalUtxo)) -> do
            (finalUtxo', _) <- runIntT' ctxt $ int @DSL2Cardano dslUtxo
            if finalUtxo == finalUtxo'
              then return $ ExpectedValid
              else return . Disagreement ledger
                  $ UnexpectedUtxo dslUtxo finalUtxo finalUtxo'
  where
    -- In order to limit the `Attributes` size in a Tx, `TxValidationRules` was created
    -- in https://github.com/the-blockchain-company/bcc-sl/pull/3878. The value is checked in
    -- `checkTx` which `verifyBlocksPrefix` eventually calls. Because this module tests that
    -- the UTxO spec is adhered too, it is acceptable to use a dummy value (`dummyTxValRules`)
    -- to avoid unrelated failures in `checkTx`. The alternative is to thread `TxValidationRules`
    -- throughout this test suite (and potentially others) which would be a waste of time.
    -- This dummy value will not result in failure because the `currentEpoch` is before the
    -- `cutOffEpoch` and the validation rules are only evaluated when the `currentEpoch` has
    -- passed the `cutOffEpoch`.
    dummyTxValRules = TxValidationRules
                          cutOffEpoch
                          currentEpoch
                          addAttribSizeRes
                          txAttribSizeRes
    -- The epoch from which the validation rules in `checkTx` are enforced.
    cutOffEpoch = EpochIndex 1
    -- The current epoch that the node sees.
    currentEpoch = EpochIndex 0
    -- The size limit of `Addr Attributes`.
    addAttribSizeRes = 128
    -- The size limit of `TxAttributes`.
    txAttribSizeRes = 128

{-------------------------------------------------------------------------------
  Chain verification test result
-------------------------------------------------------------------------------}

data ValidationResult h a =
    -- | We expected the chain to be valid; DSL and Bcc both agree
    ExpectedValid

    -- | We expected the chain to be invalid; DSL and Bcc both agree
    -- ExpectedInvalid
    --     validationErrorDsl
    --     validationErrorCardano
  | ExpectedInvalid !Text !Bcc.VerifyBlocksException

    -- | Variation on 'ExpectedInvalid', where we cannot even /construct/
    -- the Bcc chain, much less validate it.
    -- ExpectedInvalid
    --     validationErrorDsl
    --     validationErrorInt
  | ExpectedInvalid'  !Text !IntException

    -- | Disagreement between the DSL and Bcc
    --
    -- This indicates a bug. Of course, the bug could be in any number of
    -- places:
    --
    -- * Our translatiom from the DSL to Bcc is wrong
    -- * There is a bug in the DSL definitions
    -- * There is a bug in the Bcc implementation
    --
    -- We record the error message from Bcc, if Bcc thought the chain
    -- was invalid, as well as the ledger that causes the problem.
    -- Disagreement
    --     validationLedger
    --     validationDisagreement
  | Disagreement !(Ledger h a) !(Disagreement h a)

-- | Disagreement between Bcc and the DSL
--
-- We consider something to be "unexpectedly foo" when Bcc says it's
-- " foo " but the DSL says it's " not foo "; the DSL is the spec, after all
-- (of course that doesn't mean that it cannot contain bugs :).
data Disagreement h a =
    -- | Bcc reported the chain as invalid, but the DSL reported it as
    -- valid. We record the error message from Bcc.
    UnexpectedInvalid Bcc.VerifyBlocksException

    -- | Bcc reported an error during chain translation, but the DSL
    -- reported it as valid.
  | UnexpectedError IntException

    -- | Bcc reported the chain as valid, but the DSL reported it as
    -- invalid.
  | UnexpectedValid Text

    -- | Both Bcc and the DSL reported the chain as valid, but they computed
    -- a different UTxO
    -- UnexpectedUtxo utxoDsl utxoCardano utxoInt
  | UnexpectedUtxo !(Utxo h a) !Bcc.Utxo !Bcc.Utxo

expectValid :: ValidationResult h a -> Bool
expectValid ExpectedValid = True
expectValid _otherwise    = False

expectInvalid :: ValidationResult h a -> Bool
expectInvalid (ExpectedInvalid _ _) = True
expectInvalid _otherwise            = False

{-------------------------------------------------------------------------------
  Pretty-printing
-------------------------------------------------------------------------------}

instance (Hash h a, Buildable a) => Buildable (ValidationResult h a) where
  build ExpectedValid = "ExpectedValid"
  build (ExpectedInvalid
             validationErrorDsl
             validationErrorCardano) = bprint
      ( "ExpectedInvalid"
      % ", errorDsl:     " % build
      % ", errorCardano: " % build
      % "}"
      )
      validationErrorDsl
      validationErrorCardano
  build (ExpectedInvalid'
             validationErrorDsl
             validationErrorInt) = bprint
      ( "ExpectedInvalid'"
      % ", errorDsl: " % build
      % ", errorInt: " % build
      % "}"
      )
      validationErrorDsl
      validationErrorInt
  build (Disagreement
             validationLedger
             validationDisagreement) = bprint
      ( "Disagreement "
      % "{ ledger: "       % build
      % ", disagreement: " % build
      % "}"
      )
      validationLedger
      validationDisagreement

instance (Hash h a, Buildable a) => Buildable (Disagreement h a) where
  build (UnexpectedInvalid e) = bprint ("UnexpectedInvalid " % build) e
  build (UnexpectedError e)   = bprint ("UnexpectedError " % shown) e
  build (UnexpectedValid e)   = bprint ("UnexpectedValid " % shown) e
  build (UnexpectedUtxo utxoDsl utxoCardano utxoInt) = bprint
      ( "UnexpectedUtxo"
      % "{ dsl:     " % build
      % ", bcc: " % mapJson
      % ", int:     " % mapJson
      % "}"
      )
      utxoDsl
      utxoCardano
      utxoInt
