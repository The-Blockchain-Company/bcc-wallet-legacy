{-# LANGUAGE ViewPatterns #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Test.Spec.Submission (
    spec
  ) where

import           Universum hiding (elems)

import           Bcc.Wallet.Kernel.DB.HdRootId (HdRootId, eskToHdRootId)
import           Bcc.Wallet.Kernel.DB.HdWallet (HdAccountId (..),
                     HdAccountIx (..))
import           Bcc.Wallet.Kernel.DB.Spec.Pending (Pending)
import qualified Bcc.Wallet.Kernel.DB.Spec.Pending as Pending
import           Bcc.Wallet.Kernel.Submission
import           Control.Lens (anon, at, to)
import qualified Data.ByteString as BS
import qualified Data.List as List
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map as M
import           Data.Set (Set)
import qualified Data.Set as S
import qualified Data.Vector as V
import           Formatting (bprint, (%))
import qualified Formatting as F
import           Formatting.Buildable (build)
import qualified Pos.Chain.Txp as Txp
import           Pos.Core.Attributes (Attributes (..), UnparsedFields (..))
import           Pos.Core.NetworkMagic (NetworkMagic (..))
import           Pos.Crypto (ProtocolMagic (..), RequiresNetworkMagic (..))
import           Pos.Crypto.Hashing (hash)
import           Pos.Crypto.Signing.Safe (safeDeterministicKeyGen)
import           Serokell.Util.Text (listJsonIndent)
import qualified Test.Pos.Chain.Txp.Arbitrary as Txp

import           Test.QuickCheck (Gen, Property, arbitrary, choose, conjoin,
                     forAll, generate, listOf, shuffle, vectorOf,
                     withMaxSuccess, (===))
import           Test.QuickCheck.Property (counterexample)
import           Util.Buildable (ShowThroughBuild (..))
import           Util.Buildable.Hspec
import           UTxO.Util (disjoint)

{-# ANN module ("HLint: ignore Reduce duplication" :: Text) #-}

{-------------------------------------------------------------------------------
  QuickCheck core-based generators, which cannot be placed in the normal
  modules without having `wallet-new` depends from `bcc-sl-txp-test`.
-------------------------------------------------------------------------------}

genPending :: ProtocolMagic -> Gen Pending
genPending pMagic = do
    elems <- listOf (do tx  <- Txp.genTx
                        wit <- (V.fromList <$> listOf (Txp.genTxInWitness pMagic))
                        Txp.TxAux <$> pure tx <*> pure wit
                    )
    return $ Pending.fromTransactions elems

-- | An hardcoded 'HdAccountId'.
myAccountId :: HdAccountId
myAccountId = HdAccountId {
      _hdAccountIdParent = myHdRootId
    , _hdAccountIdIx     = HdAccountIx 0x42
    }
    where
        myHdRootId :: HdRootId
        myHdRootId = (eskToHdRootId NetworkMainOrStage) .
                               snd .
                               safeDeterministicKeyGen (BS.pack (replicate 32 0)) $ mempty

-- Generates a random schedule by picking a slot >= of the input one but
-- within a 'slot + 10' range, as really generating schedulers which generates
-- things too far away in the future is not very useful for testing, if not
-- testing that a scheduler will never reschedule something which cannot be
-- reached.
genSchedule :: MaxRetries -> Map HdAccountId Pending -> Slot -> Gen Schedule
genSchedule maxRetries pending (Slot lowerBound) = do
    let pendingTxs  = pending ^. at myAccountId
                               . anon Pending.empty Pending.null
                               . to Pending.toList
    slots    <- vectorOf (length pendingTxs) (fmap Slot (choose (lowerBound, lowerBound + 10)))
    retries  <- vectorOf (length pendingTxs) (choose (0, maxRetries))
    let events = List.foldl' updateFn mempty (zip3 slots pendingTxs retries)
    return $ Schedule events mempty
    where
        updateFn acc (slot, (txId, txAux), retries) =
            let s = ScheduleSend myAccountId txId txAux (SubmissionCount retries)
                e = ScheduleEvents [s] mempty
            in prependEvents slot e acc

genWalletSubmissionState :: ProtocolMagic
                         -> HdAccountId
                         -> MaxRetries
                         -> Gen WalletSubmissionState
genWalletSubmissionState pm accId maxRetries = do
    pending   <- M.singleton accId <$> genPending pm
    let slot  = Slot 0 -- Make the layer always start from 0, to make running the specs predictable.
    scheduler <- genSchedule maxRetries pending slot
    return $ WalletSubmissionState pending scheduler slot

genWalletSubmission :: ProtocolMagic
                    -> HdAccountId
                    -> MaxRetries
                    -> ResubmissionFunction
                    -> Gen WalletSubmission
genWalletSubmission pm accId maxRetries rho =
    WalletSubmission <$> pure rho <*> genWalletSubmissionState pm accId maxRetries

{-------------------------------------------------------------------------------
  Submission layer tests
-------------------------------------------------------------------------------}

instance Buildable [LabelledTxAux] where
    build xs = bprint (listJsonIndent 4) xs

instance (Buildable a) => Buildable (S.Set a) where
    build xs = bprint (listJsonIndent 4) (S.toList xs)

instance (Buildable a) => Buildable (Map HdAccountId a) where
    build xs = bprint (listJsonIndent 4) (M.toList xs)

constantResubmit :: ResubmissionFunction
constantResubmit = giveUpAfter 255

giveUpAfter :: Int -> ResubmissionFunction
giveUpAfter retries currentSlot scheduled oldScheduler =
    let rPolicy = constantRetry 1 retries
    in defaultResubmitFunction rPolicy currentSlot scheduled oldScheduler

-- | Checks whether or not the second input is fully contained within the first.
shouldContainPending :: Pending
                     -> M.Map HdAccountId Pending
                     -> Bool
shouldContainPending p1 p2 =
    let pending1 = p1
        pending2 = p2 ^. at myAccountId . anon Pending.empty Pending.null
    in pending2 `Pending.isSubsetOf` pending1

-- | Checks that @any@ of the input transactions (in the pending set) appears
-- in the local pending set of the given 'WalletSubmission'.
doesNotContainPending :: M.Map HdAccountId Pending
                      -> WalletSubmission
                      -> Bool
doesNotContainPending p ws =
    let pending      = p ^. at myAccountId . anon Pending.empty Pending.null
        localPending = ws ^. localPendingSet myAccountId
    in Pending.disjoint localPending pending

toTxIdSet :: Pending -> Set Txp.TxId
toTxIdSet = Pending.transactionIds

toTxIdSet' :: M.Map HdAccountId Pending -> Set Txp.TxId
toTxIdSet' p = p ^. at myAccountId
                  . anon Pending.empty Pending.null
                  . to Pending.transactionIds

toTxIdSet'' :: M.Map HdAccountId (Set Txp.TxId) -> Set Txp.TxId
toTxIdSet'' p = p ^. at myAccountId . anon S.empty S.null

pendingFromTxs :: [Txp.TxAux] -> Pending
pendingFromTxs = Pending.fromTransactions

data LabelledTxAux = LabelledTxAux {
      labelledTxLabel :: String
    , labelledTxAux   :: Txp.TxAux
    }

instance Buildable LabelledTxAux where
    build labelled =
         let tx = Txp.taTx (labelledTxAux labelled)
         in bprint (F.shown % " [" % F.build % "] -> " % listJsonIndent 4) (labelledTxLabel labelled) (hash tx) (inputsOf tx)
      where
          inputsOf :: Txp.Tx -> [Txp.TxIn]
          inputsOf tx = NonEmpty.toList (Txp._txInputs tx)

-- Generates 4 transactions A, B, C, D such that
-- D -> C -> B -> A (C depends on B which depends on A)
dependentTransactions :: ProtocolMagic -> Gen (LabelledTxAux, LabelledTxAux, LabelledTxAux, LabelledTxAux)
dependentTransactions pm = do
    let emptyAttributes = Attributes () (UnparsedFields mempty)
    inputForA  <- (Txp.TxInUtxo <$> arbitrary <*> arbitrary)
    outputForA <- (Txp.TxOut <$> arbitrary <*> arbitrary)
    outputForB <- (Txp.TxOut <$> arbitrary <*> arbitrary)
    outputForC <- (Txp.TxOut <$> arbitrary <*> arbitrary)
    outputForD <- (Txp.TxOut <$> arbitrary <*> arbitrary)
    (a,b,c,d) <- let g = Txp.genTxAux pm in (,,,) <$> g <*> g <*> g <*> g
    let a' = a { Txp.taTx = (Txp.taTx a) {
                     Txp._txInputs  = inputForA :| mempty
                   , Txp._txOutputs = outputForA :| mempty
                   , Txp._txAttributes = emptyAttributes
                   }
               }
    let b' = b { Txp.taTx = (Txp.taTx b) {
                     Txp._txInputs = Txp.TxInUtxo (hash (Txp.taTx a')) 0 :| mempty
                   , Txp._txOutputs = outputForB :| mempty
                   , Txp._txAttributes = emptyAttributes
                   }
               }
    let c' = c { Txp.taTx = (Txp.taTx c) {
                     Txp._txInputs = Txp.TxInUtxo (hash (Txp.taTx b')) 0 :| mempty
                   , Txp._txOutputs = outputForC :| mempty
                   , Txp._txAttributes = emptyAttributes
                   }
               }
    let d' = d { Txp.taTx = (Txp.taTx d) {
                     Txp._txInputs = Txp.TxInUtxo (hash (Txp.taTx c')) 0 :| mempty
                   , Txp._txOutputs = outputForD :| mempty
                   , Txp._txAttributes = emptyAttributes
                   }
               }
    return ( LabelledTxAux "B" b'
           , LabelledTxAux "C" c'
           , LabelledTxAux "A" a'
           , LabelledTxAux "D" d'
           )

---
--- Pure generators, running in Identity
---
genPureWalletSubmission :: ProtocolMagic -> HdAccountId -> Gen (ShowThroughBuild WalletSubmission)
genPureWalletSubmission pm accId =
    STB <$> genWalletSubmission pm accId 255 constantResubmit

genPurePair :: ProtocolMagic -> Gen (ShowThroughBuild (WalletSubmission, M.Map HdAccountId Pending))
genPurePair pm = do
    STB layer <- genPureWalletSubmission pm myAccountId
    pending <- genPending pm
    let pending' = Pending.delete (toTxIdSet $ layer ^. localPendingSet myAccountId) pending
    pure $ STB (layer, M.singleton myAccountId pending')

class ToTxIds a where
    toTxIds :: a -> [Txp.TxId]

instance ToTxIds Txp.TxAux where
    toTxIds tx = [hash (Txp.taTx tx)]

instance ToTxIds LabelledTxAux where
    toTxIds (LabelledTxAux _ txAux) = toTxIds txAux

instance ToTxIds a => ToTxIds [a] where
    toTxIds = mconcat . map toTxIds

instance ToTxIds Pending where
    toTxIds = S.toList . Pending.transactionIds

instance ToTxIds ScheduleSend where
    toTxIds (ScheduleSend _ txId _ _) = [txId]

failIf :: (Buildable a, Buildable b) => String -> (a -> b -> Bool) -> a -> b -> Property
failIf label f x y =
  counterexample (show (STB x) ++ interpret res ++ show (STB y)) res
  where
    res = f x y
    interpret True  = " failIf succeeded "
    interpret False = " " <> label <> " "

isSubsetOf :: (Buildable a, Ord a) => S.Set a -> S.Set a -> Property
isSubsetOf = failIf "not infix of" S.isSubsetOf

includeEvent :: String -> ScheduleEvents -> LabelledTxAux -> Property
includeEvent label se tx =
    failIf (label <> ": doesn't include event")
           (\t s -> hash (Txp.taTx (labelledTxAux t)) `List.elem` toTxIds (s ^. seToSend)) tx se

includeEvents :: String -> ScheduleEvents -> [LabelledTxAux] -> Property
includeEvents label se txs = failIf (label <> ": not includes all of") checkEvent se txs
    where
        checkEvent :: ScheduleEvents -> [LabelledTxAux] -> Bool
        checkEvent (ScheduleEvents toSend _) =
          all (\t -> hash (Txp.taTx (labelledTxAux t)) `List.elem` toTxIds toSend)

mustNotIncludeEvents :: String -> ScheduleEvents -> [LabelledTxAux] -> Property
mustNotIncludeEvents label se txs = failIf (label <> ": does include one of") checkEvent se txs
    where
        checkEvent :: ScheduleEvents -> [LabelledTxAux] -> Bool
        checkEvent (ScheduleEvents toSend _) =
          all (\t -> not $ hash (Txp.taTx (labelledTxAux t)) `List.elem` toTxIds toSend)

addPending' :: M.Map HdAccountId Pending
            -> WalletSubmission
            -> WalletSubmission
addPending' m ws = M.foldlWithKey' (\acc k v -> addPending k v acc) ws m


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
    describe "Test wallet submission layer" $ do

      it "supports addition of pending transactions" $
          withMaxSuccess 5 $ forAll (genPurePair pm) $ \(unSTB -> (submission, toAdd)) ->
              let currentSlot = submission ^. getCurrentSlot
                  submission' = addPending' toAdd submission
                  schedule = submission' ^. getSchedule
                  ((ScheduleEvents toSend _),_) = scheduledFor (mapSlot succ currentSlot) schedule
              in conjoin [
                   failIf "localPending set not updated" shouldContainPending (submission' ^. localPendingSet myAccountId) toAdd
                   -- Check that all the added transactions are scheduled for the next slot
                 , failIf "not infix of" S.isSubsetOf (toTxIdSet' toAdd) (S.fromList $ toTxIds toSend)
                 ]

      it "supports deletion of pending transactions" $
          withMaxSuccess 5 $ forAll (genPurePair pm) $ \(unSTB -> (submission, toRemove)) ->
              doesNotContainPending toRemove $ remPendingById myAccountId (toTxIdSet' toRemove) submission

      it "remPending . addPending = id" $
          withMaxSuccess 5 $ forAll (genPurePair pm) $ \(unSTB -> (submission, pending)) ->
              let originallyPending = submission ^. localPendingSet myAccountId
                  currentlyPending  = view (localPendingSet myAccountId)
                                           (remPendingById myAccountId
                                                           (toTxIdSet' pending)
                                                           (addPending' pending submission)
                                           )
              in failIf "the two pending set are not equal" ((==) `on` Pending.transactions) originallyPending currentlyPending

      it "increases its internal slot after ticking" $ do
          withMaxSuccess 5 $ forAll (genPureWalletSubmission pm myAccountId) $ \(unSTB -> submission) ->
              let slotNow  = submission ^. getCurrentSlot
                  (_, _, ws') = tick submission
                  in failIf "internal slot didn't increase" (==) (ws' ^. getCurrentSlot) (mapSlot succ slotNow)

      it "constantRetry works predictably" $ do
           let policy = constantRetry 1 5
           conjoin [
                policy (SubmissionCount 0) (Slot 0) === SendIn (Slot 1)
              , policy (SubmissionCount 1) (Slot 1) === SendIn (Slot 2)
              , policy (SubmissionCount 2) (Slot 2) === SendIn (Slot 3)
              , policy (SubmissionCount 3) (Slot 3) === SendIn (Slot 4)
              , policy (SubmissionCount 4) (Slot 4) === SendIn (Slot 5)
              , policy (SubmissionCount 5) (Slot 5) === CheckConfirmedIn (Slot 6)
              ]

      it "limit retries correctly" $ do
          withMaxSuccess 5 $ forAll (genPurePair pm) $ \(unSTB -> (ws, pending)) ->
              let ws' = (addPending' pending ws) & wsResubmissionFunction .~ giveUpAfter 3
                  (evicted1, _, ws1) = tick ws'
                  (evicted2, _, ws2) = tick ws1
                  (evicted3, _, ws3) = tick ws2
                  (evicted4, _, ws4) = tick ws3
                  (evicted5, _, ws5) = tick ws4
                  (evicted6, _, _) = tick ws5
              in conjoin [
                   failIf "evicted1 includes any of pending" (\e p -> disjoint (toTxIdSet' p) (toTxIdSet'' e)) evicted1 pending
                 , failIf "evicted2 includes any of pending" (\e p -> disjoint (toTxIdSet' p) (toTxIdSet'' e)) evicted2 pending
                 , failIf "evicted3 includes any of pending" (\e p -> disjoint (toTxIdSet' p) (toTxIdSet'' e)) evicted3 pending
                 , failIf "evicted4 includes any of pending" (\e p -> disjoint (toTxIdSet' p) (toTxIdSet'' e)) evicted4 pending
                 , failIf "evicted5 doesn't contain all pending" (\e p -> (toTxIdSet' p) `S.isSubsetOf` (toTxIdSet'' e)) evicted5 pending
                 , failIf "evicted6 contains something from evicted5" (\e6 e5 -> disjoint (toTxIdSet'' e5) (toTxIdSet'' e6)) evicted6 evicted5
                 ]

      describe "tickSlot" $ do
          -- Given A,B,C,D where D `dependsOn` C `dependsOn` B `dependsOn` A,
          -- check that if these 4 are all scheduled within the same slot, they
          -- are all scheduled for submission.
          it "Given D->C->B->A all in the same slot, they are all sent" $ do
              let generator = do (b,c,a,d) <- dependentTransactions pm
                                 ws  <- addPending myAccountId (pendingFromTxs (map labelledTxAux [a,b,c,d])) . unSTB <$> genPureWalletSubmission pm myAccountId
                                 txs <- shuffle [b,c,a,d]
                                 return $ STB (ws, txs)
              withMaxSuccess 5 $ forAll generator $ \(unSTB -> (submission, txs)) ->
                  let currentSlot = submission ^. getCurrentSlot
                      schedule = submission ^. getSchedule
                      nxtSlot = mapSlot succ currentSlot
                      scheduledEvents = fst (scheduledFor nxtSlot schedule)
                      -- Tick directly the next slot, as 'addPending' schedules
                      -- everything for @currentSlot + 1@.
                      result = tickSlot nxtSlot submission
                  in case result of
                         (toSend, _, _) -> conjoin [
                               includeEvents "[a,b,c,d] not scheduled" scheduledEvents txs
                             , S.fromList (toTxIds txs) `isSubsetOf` S.fromList (toTxIds toSend)
                             ]

          -- Given A,B,C,D where D `dependsOn` C `dependsOn` B `dependsOn` A,
          -- if [A,B,C] are scheduled on slot 2 and [D] on slot 1, we shouldn't
          -- send anything.
          it "Given D->C->B->A, if C,B,A are in the future, D is not sent this slot" $ do
              let generator = do (b,c,a,d) <- dependentTransactions pm
                                 ws  <- addPending myAccountId (pendingFromTxs (map labelledTxAux [a,b,c])) . unSTB <$> genPureWalletSubmission pm myAccountId
                                 return $ STB (addPending myAccountId (pendingFromTxs (map labelledTxAux [d])) ((\(_,_,s) -> s) . tick $ ws), d)
              withMaxSuccess 5 $ forAll generator $ \(unSTB -> (submission, d)) ->
                  let currentSlot = submission ^. getCurrentSlot
                      schedule = submission ^. getSchedule
                      nxtSlot = mapSlot succ currentSlot
                      scheduledEvents = fst (scheduledFor nxtSlot schedule)
                      -- Tick directly the next slot, as 'addPending' schedules
                      -- everything for @currentSlot + 1@.
                      result = tickSlot nxtSlot submission
                  in case result of
                         (toSend, _, _) -> conjoin [
                               includeEvent "d scheduled" scheduledEvents d
                             , failIf "is subset of"
                                         (\x y -> not $ S.isSubsetOf x y)
                                         (S.fromList (toTxIds [d]))
                                         (S.fromList (toTxIds toSend))
                             ]

          -- Given A,B,C,D where D `dependsOn` C `dependsOn` B `dependsOn` A, if:
          -- * [A,B] are scheduled on slot 1
          -- * [D] is scheduled on slot 2
          -- * [C] is scheduled on slot 3
          -- Then during slot 1 we would send both [A,B], on slot 2 we won't send
          -- anything and finally on slot 3 we would send [C,D].
          it "Given D->C->B->A, can send [A,B] now, [D,C] in the future" $ do
              let generator :: Gen (ShowThroughBuild (WalletSubmission, [LabelledTxAux]))
                  generator = do (b,c,a,d) <- dependentTransactions pm
                                 ws  <- addPending myAccountId (pendingFromTxs (map labelledTxAux [a,b])) . unSTB <$> genPureWalletSubmission pm myAccountId
                                 let (_, _, ws')  = tick ws
                                 let ws'' = addPending myAccountId (pendingFromTxs (map labelledTxAux [d])) ws'
                                 return $ STB (ws'', [a,b,c,d])

              withMaxSuccess 5 $ forAll generator $ \(unSTB -> (submission1, [a,b,c,d])) ->
                  let slot1     = submission1 ^. getCurrentSlot
                      (scheduledInSlot1, confirmed1, _) = tickSlot slot1 submission1

                      -- Let's assume that @A@ and @B@ finally are adopted,
                      -- and the wallet calls 'remPending' on them.
                      modifyPending = addPending myAccountId (pendingFromTxs (map labelledTxAux [c]))
                                    . remPendingById myAccountId (toTxIdSet (pendingFromTxs (map labelledTxAux [a,b])))
                      (_, _, submission2) = (\(e,s,st) -> (e, s, modifyPending st)) . tick $ submission1

                      -- We are in slot 2 now. During slot 2, @D@ is scheduled and
                      -- we add @C@ to be sent during slot 3. However, due to
                      -- the fact @D@ is depedent on @C@, the scheduler shouldn't
                      -- schedule @D@, this slot, which will end up in the
                      -- nursery.
                      slot2 = submission2 ^. getCurrentSlot
                      (scheduledInSlot2, confirmed2, _) = tickSlot slot2 submission2
                      (_, _, submission3) = tick submission2

                      -- Finally, during slot 3, both @C@ and @D@ are sent.

                      slot3 = submission3 ^. getCurrentSlot
                      (scheduledInSlot3, confirmed3, _) = tickSlot slot3 submission3

                  in conjoin [
                         slot1 === Slot 1
                       , slot2 === Slot 2
                       , slot3 === Slot 3
                       , includeEvents "[a,b] scheduled slot 1" (ScheduleEvents scheduledInSlot1 confirmed1) [a,b]
                       , mustNotIncludeEvents "none of [a,b,c,d] was scheduled" (ScheduleEvents scheduledInSlot2 confirmed2) [a,b,c,d]
                       , includeEvents "[c,d] scheduled slot 3" (ScheduleEvents scheduledInSlot3 confirmed3) [c,d]
                       ]
