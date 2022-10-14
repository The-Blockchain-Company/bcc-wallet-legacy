module Test.Integration.Documentation
    ( spec
    ) where

import           Universum

import           Test.Hspec (Spec, it, shouldSatisfy)

import           Bcc.Wallet.Client.Http (WalletDocHttpClient)
import qualified Bcc.Wallet.Client.Http as Client

spec :: WalletDocHttpClient -> Spec
spec client = do
    it "Fetches the documentation from the API" $ do
        response <- runExceptT $ Client.getSwaggerJson client
        response `shouldSatisfy` isRight
