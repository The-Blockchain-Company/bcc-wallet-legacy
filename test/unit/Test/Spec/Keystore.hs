{-# OPTIONS_GHC -fno-warn-orphans       #-}
{-# LANGUAGE ViewPatterns #-}
module Test.Spec.Keystore (
    spec
  ) where

import           Universum

import           System.Directory (doesFileExist, removeFile)
import           System.IO.Error (IOError)

import           Test.Hspec (Spec, describe, it, shouldBe, shouldReturn,
                     shouldSatisfy)
import           Test.Hspec.Core.Spec (sequential)
import           Test.Hspec.QuickCheck (prop)
import           Test.QuickCheck (Gen, arbitrary)
import           Test.QuickCheck.Monadic (forAllM, monadicIO, pick, run)

import           Pos.Core.NetworkMagic (NetworkMagic)
import           Pos.Crypto (EncryptedSecretKey, hash, safeKeyGen)

import           Bcc.Wallet.Kernel.DB.HdRootId (HdRootId, eskToHdRootId)
import           Bcc.Wallet.Kernel.DB.HdWallet ()
import           Bcc.Wallet.Kernel.Keystore (DeletePolicy (..), Keystore)
import qualified Bcc.Wallet.Kernel.Keystore as Keystore

import           Util.Buildable (ShowThroughBuild (..))

{-# ANN module ("HLint: ignore Reduce duplication" :: Text) #-}

-- | Creates and operate on a keystore. The 'Keystore' is created in a temporary
-- directory and garbage-collected from the Operating System.
withKeystore :: (Keystore -> IO a) -> IO a
withKeystore = Keystore.bracketTestKeystore

genKeypair :: NetworkMagic
           -> Gen ( ShowThroughBuild HdRootId
                  , ShowThroughBuild EncryptedSecretKey
                  )
genKeypair nm = do
    (_, esk) <- arbitrary >>= safeKeyGen
    return $ bimap STB STB (eskToHdRootId nm esk, esk)

genKeys :: NetworkMagic
        -> Gen ( ShowThroughBuild HdRootId
               , ShowThroughBuild EncryptedSecretKey
               , ShowThroughBuild EncryptedSecretKey
               )
genKeys nm = do
    (wId, origKey) <- genKeypair nm
    (_, esk2) <- arbitrary >>= safeKeyGen
    return (wId, origKey, STB esk2)

nukeKeystore :: FilePath -> IO ()
nukeKeystore fp =
    removeFile fp `catch` (\(_ :: IOError) -> return ())

-- These test perform file-IO and cannot run in parallel.
spec :: Spec
spec =
    describe "Keystore to store UserSecret(s)" $ do
        describe "Parallelisable tests (no resource contention)" $ do

            prop "lookup of keys works" $ monadicIO $ do
                nm <- pick arbitrary
                forAllM (genKeypair nm) $ \(STB wid, STB esk) -> run $ do
                    withKeystore $ \ks -> do
                        Keystore.insert wid esk ks
                        mbKey <- Keystore.lookup nm wid ks
                        (fmap hash mbKey) `shouldBe` (Just (hash esk))

            prop "replacement of keys works" $ monadicIO $ do
                nm <- pick arbitrary
                forAllM (genKeys nm) $ \(STB wid, STB oldKey, STB newKey) -> run $ do
                    withKeystore $ \ks -> do
                        Keystore.insert wid oldKey ks
                        mbOldKey <- Keystore.lookup nm wid ks
                        result <- Keystore.compareAndReplace nm wid (const True) newKey ks
                        mbNewKey <- Keystore.lookup nm wid ks
                        result `shouldBe` Keystore.Replaced
                        (fmap hash mbOldKey) `shouldSatisfy` ((/=) (fmap hash mbNewKey))

            prop "deletion of keys works" $ monadicIO $ do
                nm <- pick arbitrary
                forAllM (genKeypair nm) $ \(STB wid, STB esk) -> run $ do
                    withKeystore $ \ks -> do
                        Keystore.insert wid esk ks
                        Keystore.delete nm wid ks
                        mbKey <- Keystore.lookup nm wid ks
                        (fmap hash mbKey) `shouldBe` Nothing


        sequential $ describe "Sequential tests (resource contention)" $ do

            it "creating a brand new one works" $ do
                nukeKeystore "test_keystore.key"
                Keystore.bracketKeystore KeepKeystoreIfEmpty "test_keystore.key" $ \_ks ->
                    return ()
                doesFileExist "test_keystore.key" `shouldReturn` True

            it "destroying a keystore (completely) works" $ do
                nukeKeystore "test_keystore.key"
                Keystore.bracketKeystore RemoveKeystoreIfEmpty "test_keystore.key" $ \_ks ->
                    return ()
                doesFileExist "test_keystore.key" `shouldReturn` False

            prop "Inserts are persisted after releasing the keystore" $ monadicIO $ do
                nm <- pick arbitrary
                (STB wid, STB esk) <- pick $ genKeypair nm
                run $ do
                    nukeKeystore "test_keystore.key"
                    Keystore.bracketKeystore KeepKeystoreIfEmpty "test_keystore.key" $ \keystore1 ->
                        Keystore.insert wid esk keystore1
                    Keystore.bracketKeystore KeepKeystoreIfEmpty "test_keystore.key" $ \keystore2 -> do
                        mbKey <- Keystore.lookup nm wid keystore2
                        (fmap hash mbKey) `shouldBe` (Just (hash esk))

            prop "Deletion of keys are persisted after releasing the keystore" $ monadicIO $ do
                nm <- pick arbitrary
                (STB wid, STB esk) <- pick $ genKeypair nm
                run $ do
                    nukeKeystore "test_keystore.key"
                    Keystore.bracketKeystore KeepKeystoreIfEmpty "test_keystore.key" $ \keystore1 -> do
                        Keystore.insert wid esk keystore1
                        Keystore.delete nm wid keystore1
                    Keystore.bracketKeystore KeepKeystoreIfEmpty "test_keystore.key" $ \keystore2 -> do
                        mbKey <- Keystore.lookup nm wid keystore2
                        (fmap hash mbKey) `shouldBe` Nothing
