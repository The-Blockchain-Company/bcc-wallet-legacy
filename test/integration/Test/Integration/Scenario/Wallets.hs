module Test.Integration.Scenario.Wallets
    ( spec
    ) where

import           Universum

import qualified Data.List.NonEmpty as NonEmpty

import           Bcc.Wallet.API.V1.Types
                     (EstimatedFees (feeEstimatedAmount),
                     WalletCoin (unWalletCoin))
import           Bcc.Wallet.Client.Http (ClientError, Wallet)
import qualified Bcc.Wallet.Client.Http as Client
import           Pos.Core (Coin (getCoin))
import           Test.Hspec (describe)
import           Test.Integration.Framework.DSL

spec :: Scenarios Context
spec = do
    scenario "WALLETS_DELETE_01 - deleted wallet is not available" $ do
        fixture <- setup $ defaultSetup

        successfulRequest $ Client.deleteWallet
            $- (fixture ^. wallet . walletId)

        response02 <- request $ Client.getWallet
            $- (fixture ^. wallet . walletId)

        verify response02
            [ expectWalletError (WalletNotFound)
            ]

    scenario "WALLETS_DELETE_02 - Providing non-existing wallet id returns 404 error and appropriate error message." $ do
        fixture <- setup $ defaultSetup

        successfulRequest $ Client.deleteWallet
            $- (fixture ^. wallet . walletId)

        response02 <- request $ Client.deleteWallet
            $- (fixture ^. wallet . walletId)

        verify response02
            [ expectWalletError (WalletNotFound)
            ]

    describe "WALLETS_DELETE_02 - Providing not valid wallet id returns 404 error and appropriate error message." $ do
        forM_ (["", "123", "ziemniak"]) $ \(notValidId) -> scenario ("walId = \"" ++ notValidId ++ "\"") $ do
            let endpoint = "api/v1/wallets/" ++ notValidId
            response <- unsafeRequest ("DELETE", fromString endpoint) $ Nothing
            verify (response :: Either ClientError EosWallet)
                [ expectError
                -- TODO: add more expectations after #221 is resolved
                ]

    scenario "WALLETS_DELETE_03 - Deleted wallet does not appear in the Client.getWallets" $ do
        fixture <- setup $ defaultSetup

        successfulRequest $ Client.deleteWallet
            $- (fixture ^. wallet . walletId)

        resp <- request $ Client.getWallets
        verify resp
            [ expectSuccess
            , expectListSizeEqual 0
            ]

    scenario "WALLETS_DETAILS_01 - one gets all wallet details when providing valid wallet id" $ do
        fixture  <- setup defaultSetup
        response <- request $ Client.getWallet $- fixture ^. wallet . walletId
        verify response
            [ expectFieldEqual walletId (fixture ^. wallet . walletId)
            , expectFieldEqual assuranceLevel defaultAssuranceLevel
            , expectFieldEqual walletName defaultWalletName
            , expectFieldEqual createdAt (fixture ^. wallet . createdAt)
            , expectFieldEqual spendingPasswordLastUpdate (fixture ^. wallet . spendingPasswordLastUpdate)
            , expectFieldEqual syncState (fixture ^. wallet . syncState)
            , expectFieldEqual hasSpendingPassword False
            , expectFieldEqual amount 0
            ]

    scenario "WALLETS_DETAILS_02, WALLETS_DELETE_05 - Providing non-existing wallet id returns 404 error and appropriate error message." $ do
        fixture  <- setup defaultSetup

        _ <- successfulRequest $ Client.deleteWallet $- fixture ^. wallet . walletId

        getWal <- request $ Client.getWallet $- fixture ^. wallet . walletId
        verify getWal
            [ expectWalletError (WalletNotFound)
            ]

    describe "WALLETS_DETAILS_02 - Providing not valid wallet id returns 404 error and appropriate error message." $ do
        forM_ (["", "123", "ziemniak"]) $ \(notValidId) -> scenario ("walId = \"" ++ notValidId ++ "\"") $ do
            let endpoint = "api/v1/wallets/" ++ notValidId
            response <- unsafeRequest ("GET", fromString endpoint) $ Nothing
            verify (response :: Either ClientError EosWallet)
                [ expectError
                -- TODO: add more expectations after #221 is resolved
                ]

    scenario "WALLETS_DETAILS_04 - Receiving and sending funds updates 'balance' field accordingly" $ do
        fixtureSource <- setup $ defaultSetup
            & initialCoins .~ [10000000]
        fixtureDest <- setup $ defaultSetup
        accountDest <- successfulRequest $ Client.getAccount
            $- (fixtureDest ^. wallet . walletId)
            $- defaultAccountId

        getSource <- request $ Client.getWallet $- fixtureSource ^. wallet . walletId
        verify getSource
            [ expectFieldEqual amount 10000000
            ]
        getDest <- request $ Client.getWallet $- fixtureDest ^. wallet . walletId
        verify getDest
            [ expectFieldEqual amount 0
            ]

        fee <- fmap (getCoin . unWalletCoin . feeEstimatedAmount) $ successfulRequest $ Client.getTransactionFee $- Payment
            (defaultSource fixtureSource)
            (customDistribution $ NonEmpty.zipWith (,) (accountDest :| []) (10 :| []))
            defaultGroupingPolicy
            (Just $ defaultSpendingPassword)

        respPayment <- request $ Client.postTransaction $- Payment
            (defaultSource fixtureSource)
            (customDistribution $ NonEmpty.zipWith (,) (accountDest :| []) (10 :| []))
            defaultGroupingPolicy
            (Just $ defaultSpendingPassword)
        verify respPayment
            [ expectTxStatusEventually [InNewestBlocks, Persisted]
            ]
        getSourceAfter <- request $ Client.getWallet $- fixtureSource ^. wallet . walletId
        verify getSourceAfter
            [ expectFieldEqual amount (10000000 - 10 - fee)
            ]
        getDestAfter <- request $ Client.getWallet $- fixtureDest ^. wallet . walletId
        verify getDestAfter
            [ expectFieldEqual amount 10
            ]

    scenario "WALLETS_LIST_01 - One can list all wallets without providing any parameters" $ do
        fixtures <- forM (zip [1..3] [NormalAssurance, NormalAssurance, StrictAssurance]) $ \(name, level) -> do
            setup $ defaultSetup
                & walletName .~ show (name :: Int)
                & assuranceLevel .~ level
        forM_ fixtures $ \fixture -> do
            response <- request $ Client.getWallet
                $- (fixture ^. wallet . walletId)
            verify response
                [ expectFieldEqual walletName (fixture ^. wallet . walletName)
                , expectFieldEqual assuranceLevel (fixture ^. wallet .  assuranceLevel)
                ]

        getWalletsResp <- request $ Client.getWallets
        verify getWalletsResp
            [ expectSuccess
            , expectListSizeEqual 3
            ]

    describe "WALLETS_LIST_02 - One can set page >= 1 and per_page [1..50] on the results." $ do

        let failingScenario = "1 wallet; page=9223372036854775807 & per_page=50 => 0 wallets returned"

        let matrix =
                [ ( "2 wallets; page=1 & per_page=1 => 1 wallet returned"
                  , 2
                  , Just (Client.Page 1)
                  , Just (Client.PerPage 1)
                  , [ expectSuccess
                    , expectListSizeEqual 1
                    ]
                  )
                , ( "6 wallets; page=3 & per_page=2 => 2 wallets returned"
                  , 6
                  , Just (Client.Page 3)
                  , Just (Client.PerPage 2)
                  , [ expectSuccess
                    , expectListSizeEqual 2
                    ]
                  )
                , ( "4 wallets; per_page=3 => 3 wallets returned"
                  , 4
                  , Nothing
                  , Just (Client.PerPage 3)
                  , [ expectSuccess
                    , expectListSizeEqual 3
                    ]
                  )
                , ( "11 wallets; page=1 => 10 wallets returned"
                  , 11
                  , Just (Client.Page 1)
                  , Nothing
                  , [ expectSuccess
                    , expectListSizeEqual 10
                    ]
                  )
                , ( failingScenario
                  , 1
                  , Just (Client.Page 9223372036854775807)
                  , Just (Client.PerPage 50)
                  , [ expectSuccess
                    , expectListSizeEqual 0
                    ]
                  )
                ]

        forM_ matrix $ \(title, walletsNumber, page, perPage, expectations) -> scenario title $ do

            forM_ ([1..walletsNumber]) $ \name -> do
                when (title == failingScenario) $
                    pendingWith "Test fails due to bug #213"

                setup $ defaultSetup
                    & walletName .~ show (name :: Int)

            response <- request $ Client.getWalletIndexFilterSorts
                $- page
                $- perPage
                $- NoFilters
                $- NoSorts
            verify response expectations

    describe "WALLETS_LIST_02 - One gets error when page and/or per_page have non-supported values" $ do

        let matrix =
                [ ( "api/v1/wallets?page=0"
                  , [ expectError
                    -- TODO: add more expectations after #221 is resolved
                    ]
                  )
                , ( "api/v1/wallets?page=-1"
                  , [ expectError
                    -- TODO: add more expectations after #221 is resolved
                    ]
                  )
                , ( "api/v1/wallets?page=0&per_page=35"
                  , [ expectError
                    -- TODO: add more expectations after #221 is resolved
                    ]
                  )
                , ( "api/v1/wallets?page=1???patate???"
                  , [ expectError
                    -- TODO: add more expectations after #221 is resolved
                    ]
                  )
                , ( "api/v1/wallets?page=9223372036854775808"
                  , [ expectError
                    -- TODO: add more expectations after #221 is resolved
                    ]
                  )
                , ( "api/v1/wallets?page=-9223372036854775809"
                  , [ expectError
                    -- TODO: add more expectations after #221 is resolved
                    ]
                  )
                , ( "api/v1/wallets?per_page=0"
                  , [ expectError
                    -- TODO: add more expectations after #221 is resolved
                    ]
                  )
                , ( "api/v1/wallets?per_page=-1&page=1"
                  , [ expectError
                    -- TODO: add more expectations after #221 is resolved
                    ]
                  )
                , ( "api/v1/wallets?per_page=51"
                  , [ expectError
                    -- TODO: add more expectations after #221 is resolved
                    ]
                  )
                , ( "api/v1/wallets?per_page=5???patate???"
                  , [ expectError
                    -- TODO: add more expectations after #221 is resolved
                    ]
                  )
                ]

        forM_ matrix $ \(endpoint, expectations) -> scenario endpoint $ do
            _ <- setup $ defaultSetup
            resp <- unsafeRequest ("GET", fromString endpoint) $ Nothing
            verify (resp :: Either ClientError [Wallet]) expectations

    scenario "WALLETS_LIST_03 - One can filter wallets by balance" $ do

        let matrix =
                [ ( "api/v1/wallets?balance=EQ%5B3%5D"
                  , [ expectSuccess
                    , expectListSizeEqual 1
                    , expectListItemFieldEqual 0 amount 3
                    ]
                  )
                , ( "api/v1/wallets?balance=6"
                  , [ expectSuccess
                    , expectListSizeEqual 2
                    , expectListItemFieldEqual 0 amount 6
                    , expectListItemFieldEqual 1 amount 6
                    ]
                  )
                , ( "api/v1/wallets?balance=LT%5B6%5D&sort_by=balance"
                  , [ expectSuccess
                    , expectListSizeEqual 2
                    , expectListItemFieldEqual 0 amount 3
                    , expectListItemFieldEqual 1 amount 1
                    ]
                  )
                , ( "api/v1/wallets?balance=GT%5B6%5D"
                  , [ expectSuccess
                    , expectListSizeEqual 1
                    , expectListItemFieldEqual 0 amount 9
                    ]
                  )
                , ( "api/v1/wallets?balance=GTE%5B6%5D&sort_by=balance"
                  , [ expectSuccess
                    , expectListSizeEqual 3
                    , expectListItemFieldEqual 0 amount 9
                    , expectListItemFieldEqual 1 amount 6
                    , expectListItemFieldEqual 2 amount 6
                    ]
                  )
                , ( "api/v1/wallets?balance=LTE%5B6%5D&sort_by=balance"
                  , [ expectSuccess
                    , expectListSizeEqual 4
                    , expectListItemFieldEqual 0 amount 6
                    , expectListItemFieldEqual 1 amount 6
                    , expectListItemFieldEqual 2 amount 3
                    , expectListItemFieldEqual 3 amount 1
                    ]
                  )
                , ( "api/v1/wallets?balance=RANGE%5B3,6%5D&sort_by=balance"
                  , [ expectSuccess
                    , expectListSizeEqual 3
                    , expectListItemFieldEqual 0 amount 6
                    , expectListItemFieldEqual 1 amount 6
                    , expectListItemFieldEqual 2 amount 3
                    ]
                  )
                , ( "api/v1/wallets?balance=RANGE%5B6,9%5D&sort_by=balance"
                  , [ expectSuccess
                    , expectListSizeEqual 3
                    , expectListItemFieldEqual 0 amount 9
                    , expectListItemFieldEqual 1 amount 6
                    , expectListItemFieldEqual 2 amount 6
                    ]
                  )
                ]

        forM_ ([3,6,6,9,1]) $ \coin ->
            setup $ defaultSetup
            & initialCoins .~ [coin]

        forM_ matrix $ \(endpoint, expectations) -> do
            resp <- unsafeRequest ("GET", fromString endpoint) $ Nothing
            verify (resp :: Either ClientError [Wallet]) expectations

    scenario "WALLETS_LIST_03 - One can filter wallets by wallet id" $ do
        -- EQ[value] : only allow values equal to value

        fixtures <- forM ([1,2]) $ \name -> do
            setup $ defaultSetup
                & walletName .~ show (name :: Int)

        let walletIds =
                [ (fixtures !! 0) ^. wallet . walletId
                , (fixtures !! 1) ^. wallet . walletId
                ]
        let endpoint = "api/v1/wallets?id=" <> ( fromWalletId $ walletIds !! 0 )

        resp <- unsafeRequest ("GET", endpoint) $ Nothing
        verify (resp :: Either ClientError [Wallet])
            [ expectSuccess
            , expectListSizeEqual 1
            , expectListItemFieldEqual 0 walletId ( walletIds !! 0 )
            ]

    scenario "WALLETS_LIST_03 - One can filter wallets by wallet id -- EQ[value]" $ do
        -- EQ[value] : only allow values equal to value

        fixtures <- forM ([1,2]) $ \name -> do
            setup $ defaultSetup
                & walletName .~ show (name :: Int)

        let walletIds =
                [ (fixtures !! 0) ^. wallet . walletId
                , (fixtures !! 1) ^. wallet . walletId
                ]
        let endpoint = "api/v1/wallets?id=EQ%5B" <> ( fromWalletId $ walletIds !! 0 ) <> ("%5D" :: Text)
        resp <- unsafeRequest ("GET", endpoint) $ Nothing
        verify (resp :: Either ClientError [Wallet])
            [ expectSuccess
            , expectListSizeEqual 1
            , expectListItemFieldEqual 0 walletId ( walletIds !! 0 )
            ]

    scenario "WALLETS_LIST_03 - One can filter wallets by wallet id -- LT[value]" $ do
        -- LT[value] : allow resource with attribute less than the value

        fixtures <- forM ([1,2]) $ \name -> do
            setup $ defaultSetup
                & walletName .~ show (name :: Int)

        let sortedWalletIds =
                sort [ fromWalletId $ (fixtures !! 0) ^. wallet . walletId
                     , fromWalletId $ (fixtures !! 1) ^. wallet . walletId
                     ]

        let endpoint = "api/v1/wallets?id=LT%5B" <> ( sortedWalletIds !! 1 ) <> ("%5D" :: Text)
        resp <- unsafeRequest ("GET", endpoint) $ Nothing
        verify (resp :: Either ClientError [Wallet])
            [ expectSuccess
            , expectListSizeEqual 1
            , expectListItemFieldEqual 0 walletId ( Client.WalletId $ sortedWalletIds !! 0 )
            ]

    scenario "WALLETS_LIST_03 - One can filter wallets by wallet id -- GT[value]" $ do
        -- GT[value] : allow objects with an attribute greater than the value

        fixtures <- forM ([1,2]) $ \name -> do
            setup $ defaultSetup
                & walletName .~ show (name :: Int)

        let sortedWalletIds =
                sort [ fromWalletId $ (fixtures !! 0) ^. wallet . walletId
                     , fromWalletId $ (fixtures !! 1) ^. wallet . walletId
                     ]

        let endpoint = "api/v1/wallets?id=GT%5B" <> ( sortedWalletIds !! 0 ) <> ("%5D" :: Text)

        resp <- unsafeRequest ("GET", endpoint) $ Nothing
        verify (resp :: Either ClientError [Wallet])
            [ expectSuccess
            , expectListSizeEqual 1
            , expectListItemFieldEqual 0 walletId ( Client.WalletId $ sortedWalletIds !! 1 )
            ]

    scenario "WALLETS_LIST_03 - One can filter wallets by wallet id -- GTE[value]" $ do
        -- GTE[value] : allow objects with an attribute at least the value

        fixtures <- forM ([1,2]) $ \name -> do
            setup $ defaultSetup
                & walletName .~ show (name :: Int)

        let walletIds =
                     [ fromWalletId $ (fixtures !! 0) ^. wallet . walletId
                     , fromWalletId $ (fixtures !! 1) ^. wallet . walletId
                     ]

        let endpoint = "api/v1/wallets?sort_by=created_at&id=GTE%5B" <> ( sort ( walletIds ) !! 0 ) <> ("%5D" :: Text)
        resp <- unsafeRequest ("GET", endpoint) $ Nothing
        verify (resp :: Either ClientError [Wallet])
            [ expectSuccess
            , expectListSizeEqual 2
            , expectListItemFieldEqual 0 walletId ( Client.WalletId $ walletIds !! 1 )
            , expectListItemFieldEqual 1 walletId ( Client.WalletId $ walletIds !! 0 )
            ]

    scenario "WALLETS_LIST_03 - One can filter wallets by wallet id -- LTE[value]" $ do
        -- LTE[value] : allow objects with an attribute at most the value

        fixtures <- forM ([1,2]) $ \name -> do
            setup $ defaultSetup
                & walletName .~ show (name :: Int)

        let walletIds =
                     [ fromWalletId $ (fixtures !! 0) ^. wallet . walletId
                     , fromWalletId $ (fixtures !! 1) ^. wallet . walletId
                     ]

        let endpoint = "api/v1/wallets?sort_by=created_at&id=LTE%5B" <> ( sort ( walletIds ) !! 1 ) <> ("%5D" :: Text)
        resp <- unsafeRequest ("GET", endpoint) $ Nothing
        verify (resp :: Either ClientError [Wallet])
            [ expectSuccess
            , expectListSizeEqual 2
            , expectListItemFieldEqual 0 walletId ( Client.WalletId $ walletIds !! 1 )
            , expectListItemFieldEqual 1 walletId ( Client.WalletId $ walletIds !! 0 )
            ]

    scenario "WALLETS_LIST_03 - One can filter wallets by wallet id -- RANGE[value]" $ do
        -- RANGE[lo,hi] : allow objects with the attribute in the range between lo and hi

        fixtures <- forM ([1,2,3]) $ \name -> do
            setup $ defaultSetup
                & walletName .~ show (name :: Int)

        let walletIds =
                     [ fromWalletId $ (fixtures !! 0) ^. wallet . walletId
                     , fromWalletId $ (fixtures !! 1) ^. wallet . walletId
                     , fromWalletId $ (fixtures !! 2) ^. wallet . walletId
                     ]
        let sortedWalletIds = sort walletIds

        let endpoint = "api/v1/wallets?sort_by=created_at&id=RANGE%5B" <> ( sortedWalletIds !! 0 )
                        <> "," <> ( sortedWalletIds !! 2 )  <> ("%5D" :: Text)

        resp <- unsafeRequest ("GET", endpoint) $ Nothing
        verify (resp :: Either ClientError [Wallet])
            [ expectSuccess
            , expectListSizeEqual 3
            , expectListItemFieldEqual 0 walletId ( Client.WalletId $ walletIds !! 2 )
            , expectListItemFieldEqual 1 walletId ( Client.WalletId $ walletIds !! 1 )
            , expectListItemFieldEqual 2 walletId ( Client.WalletId $ walletIds !! 0 )
            ]

    scenario "WALLETS_LIST_03 - One can filter wallets by wallet id -- IN[value]" $ do
        -- IN[a,b,c,d] : allow objects with the attribute belonging to one provided.

        fixtures <- forM ([1,2,3]) $ \name -> do
            setup $ defaultSetup
                & walletName .~ show (name :: Int)

        let walletIds =
                     [ fromWalletId $ (fixtures !! 0) ^. wallet . walletId
                     , fromWalletId $ (fixtures !! 1) ^. wallet . walletId
                     , fromWalletId $ (fixtures !! 2) ^. wallet . walletId
                     ]

        let endpoint = "api/v1/wallets?sort_by=created_at&id=IN%5B" <> ( walletIds !! 0 )
                        <> "," <> ( walletIds !! 2 )  <> ("%5D" :: Text)

        resp <- unsafeRequest ("GET", endpoint) $ Nothing

        verify (resp :: Either ClientError [Wallet])
            [ expectSuccess
            , expectListSizeEqual 2
            , expectListItemFieldEqual 0 walletId ( Client.WalletId $ walletIds !! 2 )
            , expectListItemFieldEqual 1 walletId ( Client.WalletId $ walletIds !! 0 )
            ]

    scenario "WALLETS_LIST_04 - One can sort results only by 'balance' and 'created_at'" $ do

        let matrix =
                [ ( "api/v1/wallets?sort_by=created_at"
                  , [ expectSuccess
                    , expectListSizeEqual 3
                    , expectListItemFieldEqual 0 walletName "3"
                    , expectListItemFieldEqual 1 walletName "2"
                    , expectListItemFieldEqual 2 walletName "1"
                    , expectListItemFieldEqual 0 amount 1
                    , expectListItemFieldEqual 1 amount 2
                    , expectListItemFieldEqual 2 amount 3
                    ]
                  )
                , ( "api/v1/wallets?sort_by=DES%5Bcreated_at%5D"
                  , [ expectSuccess
                    , expectListSizeEqual 3
                    , expectListItemFieldEqual 0 walletName "3"
                    , expectListItemFieldEqual 1 walletName "2"
                    , expectListItemFieldEqual 2 walletName "1"
                    , expectListItemFieldEqual 0 amount 1
                    , expectListItemFieldEqual 1 amount 2
                    , expectListItemFieldEqual 2 amount 3
                    ]
                  )
                , ( "api/v1/wallets?sort_by=ASC%5Bcreated_at%5D"
                  , [ expectSuccess
                    , expectListSizeEqual 3
                    , expectListItemFieldEqual 0 walletName "1"
                    , expectListItemFieldEqual 1 walletName "2"
                    , expectListItemFieldEqual 2 walletName "3"
                    , expectListItemFieldEqual 0 amount 3
                    , expectListItemFieldEqual 1 amount 2
                    , expectListItemFieldEqual 2 amount 1
                    ]
                  )
                , ( "api/v1/wallets?sort_by=balance"
                  , [ expectSuccess
                    , expectListSizeEqual 3
                    , expectListItemFieldEqual 0 walletName "1"
                    , expectListItemFieldEqual 1 walletName "2"
                    , expectListItemFieldEqual 2 walletName "3"
                    , expectListItemFieldEqual 0 amount 3
                    , expectListItemFieldEqual 1 amount 2
                    , expectListItemFieldEqual 2 amount 1
                    ]
                  )
                , ( "api/v1/wallets?sort_by=DES%5Bbalance%5D"
                  , [ expectSuccess
                    , expectListSizeEqual 3
                    , expectListItemFieldEqual 0 walletName "1"
                    , expectListItemFieldEqual 1 walletName "2"
                    , expectListItemFieldEqual 2 walletName "3"
                    , expectListItemFieldEqual 0 amount 3
                    , expectListItemFieldEqual 1 amount 2
                    , expectListItemFieldEqual 2 amount 1
                    ]
                  )
                , ( "api/v1/wallets?sort_by=ASC%5Bbalance%5D"
                  , [ expectSuccess
                    , expectListSizeEqual 3
                    , expectListItemFieldEqual 0 walletName "3"
                    , expectListItemFieldEqual 1 walletName "2"
                    , expectListItemFieldEqual 2 walletName "1"
                    , expectListItemFieldEqual 0 amount 1
                    , expectListItemFieldEqual 1 amount 2
                    , expectListItemFieldEqual 2 amount 3
                    ]
                  )
                , ( "api/v1/wallets?sort_by=???patate???"
                  , [ expectSuccess
                    , expectListSizeEqual 3
                    ]
                  )

                ]

        forM_ (zip [1,2,3] [3,2,1]) $ \(name, coins) -> do
            setup $ defaultSetup
                & walletName .~ show (name :: Int)
                & initialCoins .~ [coins]

        forM_ matrix $ \(endpoint, expectations) -> do
            resp <- unsafeRequest ("GET", fromString endpoint) $ Nothing
            verify (resp :: Either ClientError [Wallet]) expectations

    describe "WALLETS_UPDATE_PASS_01,04,05,06,09, WALLETS_DETAILS_05 - Updating password to empty and non-empty" $ do
        let matrix =
                [ ( "non-empty old and new password"
                  , "old raw password"
                  , "new raw password" :: Text
                  , [ expectFieldEqual hasSpendingPassword True ]
                  )
                , ( "old pass empty, new pass non-empty"
                  , ""
                  , "new raw password" :: Text
                  , [ expectFieldEqual hasSpendingPassword True ]
                  )
                , ( "old pass non-empty, new pass empty"
                  , "old raw password"
                  , "" :: Text
                  , [ expectFieldEqual hasSpendingPassword False ]
                  )
                , ( "empty old and new password"
                  , ""
                  , "" :: Text
                  , [ expectFieldEqual hasSpendingPassword False ]
                  )
                ]

        forM_ matrix $ \(title, oldPass, newPass, expectations) -> scenario title $ do
            fixture <- setup $ defaultSetup
                & rawPassword .~ oldPass

            let latestUpdateTime = fixture ^. wallet ^. spendingPasswordLastUpdate
            let fullExpectations = (expectFieldDiffer spendingPasswordLastUpdate latestUpdateTime) : expectations
            updatePasswordResp <- request $ Client.updateWalletPassword
                $- (fixture ^. wallet . walletId)
                $- PasswordUpdate (fixture ^. spendingPassword) (mkPassword (RawPassword newPass))
            verify updatePasswordResp fullExpectations

            response <- request $ Client.getWallet
                $- (fixture ^. wallet . walletId)
            verify response fullExpectations

    describe "WALLETS_UPDATE_01,04,05, WALLETS_DETAILS_06 - Updating wallet, updates name, assuranceLevel only" $ do
        forM_ ([(StrictAssurance, NormalAssurance), (NormalAssurance, StrictAssurance)]) $ \(initLvl, updLvl) -> scenario ((show initLvl) ++ " -> " ++ (show updLvl)) $ do
            fixture <- setup $ defaultSetup
                & assuranceLevel .~ initLvl

            let expectations = [ -- updated
                                 expectFieldEqual assuranceLevel updLvl
                               , expectFieldEqual walletName "???patate???"
                                -- not updated
                               , expectFieldEqual walletId (fixture ^. wallet . walletId)
                               , expectFieldEqual createdAt (fixture ^. wallet . createdAt)
                               , expectFieldEqual spendingPasswordLastUpdate (fixture ^. wallet . spendingPasswordLastUpdate)
                               , expectFieldEqual syncState (fixture ^. wallet . syncState)
                               , expectFieldEqual hasSpendingPassword (fixture ^. wallet . hasSpendingPassword)
                               , expectFieldEqual amount 0
                               ]

            walUpdateResp <- request $ Client.updateWallet
                    $- (fixture ^. wallet . walletId)
                    $- WalletUpdate updLvl "???patate???"
            verify walUpdateResp expectations

            getWalResp <- request $ Client.getWallet
                    $- (fixture ^. wallet . walletId)
            verify getWalResp expectations

    scenario "WALLETS_UPDATE_02, WALLETS_DELETE_04 - Invalid or non-existing 'walletId' results in response code: 404 and appropriate error message." $ do
        fixture <- setup $ defaultSetup
        successfulRequest $ Client.deleteWallet
            $- (fixture ^. wallet . walletId)

        resp <- request $ Client.updateWallet
                $- (fixture ^. wallet . walletId)
                $- WalletUpdate StrictAssurance "???patate???"
        verify resp
            [ expectWalletError (WalletNotFound)
            ]

    describe "WALLETS_UPDATE_02 - Providing not valid wallet id returns 404 error and appropriate error message." $ do
        forM_ (["", "123", "ziemniak"]) $ \(notValidId) -> scenario ("walId = \"" ++ notValidId ++ "\"") $ do
            let endpoint = "api/v1/wallets/" ++ notValidId
            response <- unsafeRequest ("PUT", fromString endpoint) $ Just $ [json|{
                "name": "new name",
                "assuranceLevel": "strict"
            }|]
            verify (response :: Either ClientError EosWallet)
                [ expectError
                -- TODO: add more expectations after #221 is resolved
                ]

    describe "WALLETS_UPDATE_03 - one has to provide all required parameters" $ do

        let matrix =
                    [ ( "no assuranceLevel"
                      , [json| { "name": "My EosWallet" } |]
                      , [ expectJSONError "the key assuranceLevel was not present." ]
                      )
                    , ( "no name"
                      , [json| { "assuranceLevel": "normal" } |]
                      , [ expectJSONError "the key name was not present." ]
                      )
                    ]
        forM_ matrix $ \(title, payload, expectations) -> scenario title $ do
            fixture  <- setup $ defaultSetup

            let endpoint = "api/v1/wallets/" <> fromWalletId (fixture ^. wallet . walletId)
            response <- unsafeRequest ("PUT", endpoint) $ Just $ [json| #{payload} |]
            verify (response :: Either ClientError EosWallet) expectations

    describe "WALLETS_UPDATE_04 - one has to provide assuranceLevel to be either 'normal' or 'strict'" $ do
        let matrix =
                [ ( "empty string"
                  , [json| "" |]
                  , [ expectJSONError "expected a String with the tag of a constructor but got ." ]
                  )
                , ( "555"
                  , [json| 555 |]
                  , [ expectJSONError "expected String but got Number." ]
                  )
                , ( "???????????iemniak???????????????"
                  , [json| "???????????iemniak???????????????" |]
                  , [ expectJSONError "expected a String with the tag of a constructor but got ???????????iemniak???????????????" ]
                  )
                ]

        forM_ matrix $ \(title, assurLevel, expectations) -> scenario ("assuranceLevel = " ++ title) $ do
            fixture  <- setup $ defaultSetup

            let endpoint = "api/v1/wallets/" <> fromWalletId (fixture ^. wallet . walletId)
            response <- unsafeRequest ("PUT", endpoint) $ Just $ [json|{
                "assuranceLevel": #{assurLevel},
                "name": "My Updated Wallet"
                }|]
            verify (response :: Either ClientError EosWallet) expectations

    describe "WALLETS_UPDATE_PASS_02,03 - Updated password makes old password invalid" $ do
        let matrix =
                [ ( "Empty new pass, non-empty old pass"
                  , "old password"
                  , "" :: Text
                  , [ expectFieldEqual hasSpendingPassword False ]
                  )
                , ( "Non-empty new pass, empty old pass"
                  , ""
                  , "valid new pass" :: Text
                  , [ expectFieldEqual hasSpendingPassword True ]
                  )
                , ( "Non-empty new pass, non-empty old pass"
                  , "old password"
                  , "valid new pass" :: Text
                  , [ expectFieldEqual hasSpendingPassword True ]
                  )
                ]

        let setupUpdatePass oldPassword newPassword expectations = do
                fixture <- setup $ defaultSetup
                    & rawPassword .~ oldPassword
                updatePasswordResp <- request $ Client.updateWalletPassword
                    $- fixture ^. wallet . walletId
                    $- PasswordUpdate (fixture ^. spendingPassword) (mkPassword (RawPassword newPassword))
                verify updatePasswordResp expectations
                return fixture

        describe "WALLETS_UPDATE_PASS_02 - Newly updated password can be used for generating new address." $ do
            forM_ matrix $ \(title, oldPassword, newPassword, expectations) -> scenario title $ do
                fixture <- setupUpdatePass oldPassword newPassword expectations
                newAddrResp <- request $ Client.postAddress $- NewAddress
                    (Just $ mkPassword (RawPassword newPassword))
                    defaultAccountId
                    (fixture ^. wallet . walletId)
                verify newAddrResp
                    [ expectAddressInIndexOf
                    ]

        describe "WALLETS_UPDATE_PASS_02 - Old password cannot be used for generating new address." $ do
            forM_ matrix $ \(title, oldPassword, newPassword, expectations) -> scenario title $ do
                fixture <- setupUpdatePass oldPassword newPassword expectations
                let walId = fixture ^. wallet . walletId
                newAddrAttemptResp <- request $ Client.postAddress $- NewAddress
                    (Just $ fixture ^. spendingPassword)
                    defaultAccountId
                    walId
                verify newAddrAttemptResp
                    [ expectWalletError (CannotCreateAddress "")
                    ]

        describe "WALLETS_UPDATE_PASS_03 - Newly updated password can be then used for sending transaction." $ do
            forM_ matrix $ \(title, oldPassword, newPassword, expectations) -> scenario title $ do
                sourceWalletFixture <- setup $ defaultSetup
                    & initialCoins .~ [4000000]
                    & rawPassword .~ oldPassword
                destinationWalletFixture <- setup $ defaultSetup

                let oldPass = sourceWalletFixture ^. spendingPassword
                let newPass = mkPassword (RawPassword newPassword)
                updatePasswordResp <- request $ Client.updateWalletPassword
                    $- sourceWalletFixture ^. wallet . walletId
                    $- PasswordUpdate oldPass newPass
                verify updatePasswordResp expectations

                transactionResp <- request $ Client.postTransaction $- Payment
                    (defaultSource sourceWalletFixture)
                    (defaultDistribution 44 destinationWalletFixture)
                    defaultGroupingPolicy
                    (Just $ newPass)
                verify transactionResp
                    [ expectTxStatusEventually [Creating, Applying, InNewestBlocks, Persisted]
                    ]

        describe "WALLETS_UPDATE_PASS_03 - Old password cannot be then used for sending transaction." $ do
            forM_ matrix $ \(title, oldPassword, newPassword, expectations) -> scenario title $ do
                sourceWalletFixture <- setup $ defaultSetup
                    & initialCoins .~ [5000000]
                    & rawPassword .~ oldPassword
                destWalletFixture <- setup $ defaultSetup

                let oldPass = sourceWalletFixture ^. spendingPassword
                let newPass = mkPassword (RawPassword newPassword)
                let walId = sourceWalletFixture ^. wallet . walletId
                updatePasswordResp <- request $ Client.updateWalletPassword
                    $- walId
                    $- PasswordUpdate oldPass newPass
                verify updatePasswordResp expectations

                transAttemptResp <- request $ Client.postTransaction $- Payment
                    (defaultSource sourceWalletFixture)
                    (defaultDistribution 44 destWalletFixture)
                    defaultGroupingPolicy
                    (Just $ oldPass)
                verify transAttemptResp
                    [ expectWalletError (CannotCreateAddress "")
                    ]

    scenario "WALLETS_UPDATE_PASS_03 - Newly updated password can be then used for redeeming certificate." $ do
        fixture <- setup $ defaultSetup
            & initialCoins .~ [5000000]
            & rawPassword .~ "old Password"

        let oldPass = fixture ^. spendingPassword
        let newPass = mkPassword (RawPassword "brand new Password")
        updatePassResp <- request $ Client.updateWalletPassword
            $- fixture ^. wallet . walletId
            $- PasswordUpdate oldPass newPass
        verify updatePassResp
            [ expectFieldEqual hasSpendingPassword True
            ]

        response <- request $ Client.redeemAda $- Redemption
            (ShieldedRedemptionCode "n0RTZ0VtVhkxSkKj2oawAZR6/lmcK6mceaY0fjsiblo=")
            noRedemptionMnemonic
            newPass
            (fixture ^. wallet . walletId)
            defaultAccountId
        verify response
            [ expectTxStatusEventually [InNewestBlocks, Persisted]
            ]

    scenario "WALLETS_UPDATE_PASS_03 - Old password cannot be then used for redeeming certificate." $ do
        fixture <- setup $ defaultSetup
            & initialCoins .~ [5000000]
            & rawPassword .~ "old Password"

        let walId = fixture ^. wallet . walletId
        let oldPass = fixture ^. spendingPassword
        let newPass = mkPassword (RawPassword "new Password")
        updatePasswordResp <- request $ Client.updateWalletPassword
            $- walId
            $- PasswordUpdate oldPass newPass
        verify updatePasswordResp
            [ expectFieldEqual hasSpendingPassword True
            ]

        response <- request $ Client.redeemAda $- Redemption
            (ShieldedRedemptionCode "iFTo/8yiCxcwMLT6wrMWecAlsKyUjYgL7hcdAJrsGfY=")
            noRedemptionMnemonic
            oldPass
            walId
            defaultAccountId
        verify response
            [ expectWalletError (CannotCreateAddress "")
            ]

    scenario "WALLETS_UPDATE_PASS_07, WALLETS_DELETE_04 - Invalid or non-existing 'walletId' results in response code: 404 and appropriate error message" $ do
        fixture <- setup $ defaultSetup
            & rawPassword .~ "valid raw pass"
        successfulRequest $ Client.deleteWallet
            $- (fixture ^. wallet . walletId)

        let oldPass = fixture ^. spendingPassword
        let newPass = mkPassword (RawPassword "new Password")
        updatePasswordResp <- request $ Client.updateWalletPassword
            $- fixture ^. wallet . walletId
            $- PasswordUpdate oldPass newPass
        verify updatePasswordResp
            [ expectError
              -- TODO: add more expectations after #221 is resolved
            ]

    scenario "WALLETS_UPDATE_PASS_07 - Invalid or non-existing 'walletId' results in response code: 404 and appropriate error message" $ do
        fixture <- setup $ defaultSetup
            & rawPassword .~ "valid raw pass"

        updatePassResp <- unsafeRequest ("PUT", "api/v1/wallets/aaa/password") $ Just $ [json|{
            "old": #{fixture ^. spendingPassword},
            "new": "3132333435363738393031323334353637383930313233343536373839303030"
        }|]
        verify (updatePassResp :: Either ClientError Wallet)
            [ expectError
              -- TODO: add more expectations after #221 is resolved
            ]

    describe "WALLETS_UPDATE_PASS_08 - Invalid or missing 'old' and 'new' result in response code: 400 and appropriate error message" $ do
        let matrix =
                [ ( "Incorrect, but valid hex"
                  , "0200020100010100020202010000000201020000020002020200010200010102" :: Text
                  )
                , ( "Incorrect, empty"
                  , "" :: Text
                  )
                ]

        forM_ matrix $ \(title, password) -> scenario title $ do
            fixture <- setup $ defaultSetup
                & rawPassword .~ "valid raw pass"

            let walId = fromWalletId (fixture ^. wallet . walletId)
            let endpoint = "api/v1/wallets/" <> walId <> ("/password" :: Text)
            updatePassResp <- unsafeRequest ("PUT", endpoint) $ Just $ [json|{
                "old": #{password},
                "new": "3132333435363738393031323334353637383930313233343536373839303030"
            }|]
            verify (updatePassResp :: Either ClientError Wallet)
                [ expectWalletError (UnknownError "")
                ]

    describe "WALLETS_UPDATE_PASS_08 - Invalid old password" $ do
        let matrix =
                [ ( "spending password is less than 32 bytes / 64 characters"
                  , [json| "5416b2988745725998907addf4613c9b0764f04959030e1b81c6" |]
                  , [ expectJSONError "Error in $.old: Expected spending password to be of either length 0 or 32, not 26" ]
                  )
                , ( "spending password is more than 32 bytes / 64 characters"
                  , [json| "c0b75cebcd14403d7abba4227cea5b99b1b09148623cd927fa7bb40c6cca5583c" |]
                  , [ expectJSONError "Error in $.old: suffix is not in base-16 format: c" ]
                  )
                , ( "spending password is a number"
                  , [json| 541 |]
                  , [ expectJSONError "Error in $.old: expected parseJSON failed for PassPhrase, encountered Number" ]
                  )
                , ( "spending password is an empty string"
                  , [json| " " |]
                  , [ expectJSONError "Error in $.old: suffix is not in base-16 format" ]
                  )
                , ( "spending password is an array"
                  , [json| [] |]
                  , [ expectJSONError "Error in $.old: expected parseJSON failed for PassPhrase, encountered Array" ]
                  )
                , ( "spending password is an arbitrary utf-8 string"
                  , [json| "patate" |]
                  , [ expectJSONError "Error in $.old: suffix is not in base-16 format" ]
                  ) -- ^ is an arbitrary string (not hex-encoded)
                ]

        forM_ matrix $ \(title, password, expectations) -> scenario title $ do
            fixture <- setup $ defaultSetup
                & rawPassword .~ "valid raw pass"

            let endpoint = "api/v1/wallets/" <> fromWalletId (fixture ^. wallet . walletId) <> ("/password" :: Text)
            updatePassResp <- unsafeRequest ("PUT", endpoint) $ Just $ [json|{
                "old": #{password},
                "new": "3132333435363738393031323334353637383930313233343536373839303030"
            }|]
            verify (updatePassResp :: Either ClientError Wallet) expectations

    describe "WALLETS_UPDATE_PASS_08 - Invalid new password" $ do
        let matrix =
                [ ( "spending password is less than 32 bytes / 64 characters"
                  , [json| "5416b2988745725998907addf4613c9b0764f04959030e1b81c6" |]
                  , [ expectJSONError "Error in $.new: Expected spending password to be of either length 0 or 32, not 26" ]
                  )
                , ( "spending password is more than 32 bytes / 64 characters"
                  , [json| "c0b75cebcd14403d7abba4227cea5b99b1b09148623cd927fa7bb40c6cca5583c" |]
                  , [ expectJSONError "Error in $.new: suffix is not in base-16 format: c" ]
                  )
                , ( "spending password is a number"
                  , [json| 541 |]
                  , [ expectJSONError "Error in $.new: expected parseJSON failed for PassPhrase, encountered Number" ]
                  )
                , ( "spending password is an empty string"
                  , [json| " " |]
                  , [ expectJSONError "Error in $.new: suffix is not in base-16 format" ]
                  )
                , ( "spending password is an array"
                  , [json| [] |]
                  , [ expectJSONError "Error in $.new: expected parseJSON failed for PassPhrase, encountered Array" ]
                  )
                , ( "spending password is an arbitrary utf-8 string"
                  , [json| "patate" |]
                  , [ expectJSONError "Error in $.new: suffix is not in base-16 format" ]
                  ) -- ^ is an arbitrary string (not hex-encoded)
                ]
        forM_ matrix $ \(title, password, expectations) -> scenario title $ do
            -- 1. Create wallet
            fixture <- setup $ defaultSetup
                & rawPassword .~ "valid raw pass"

            -- 2. Attempt to update password using invalid old password
            let endpoint = "api/v1/wallets/" <> fromWalletId (fixture ^. wallet . walletId) <> ("/password" :: Text)
            updatePassResp <- unsafeRequest ("PUT", endpoint) $ Just $ [json|{
                "old": #{fixture ^. spendingPassword},
                "new": #{password}
            }|]
            verify (updatePassResp :: Either ClientError Wallet) expectations

    scenario "WALLETS_UTXO_02, WALLETS_DELETE_06 - Providing non-existing wallet id returns 404 error and appropriate error message." $ do
        fixture <- setup $ defaultSetup

        successfulRequest $ Client.deleteWallet
            $- (fixture ^. wallet . walletId)

        resp <- request $ Client.getUtxoStatistics
            $- (fixture ^. wallet . walletId)

        verify resp
            [ expectWalletError (WalletNotFound)
            ]

    describe "WALLETS_UTXO_02 - Providing not valid wallet id returns 404 error and appropriate error message." $ do
        forM_ (["", "123", "ziemniak"]) $ \(notValidId) -> scenario ("walId = \"" ++ notValidId ++ "\"") $ do
            let endpoint = "api/v1/wallets/" ++ notValidId ++ "/statistics/utxos"
            response <- unsafeRequest ("GET", fromString endpoint) $ Nothing
            verify (response :: Either ClientError EosWallet)
                [ expectError
                -- TODO: add more expectations after #221 is resolved
                ]

    scenario "WALLETS_UTXO_01, WALLETS_UTXO_03 - UTxO statistics reflect wallet's inactivity" $ do
        fixture <- setup defaultSetup

        response <- request $ Client.getUtxoStatistics
            $- (fixture ^. wallet . walletId)

        verify response
            [ expectWalletUTxO []
            ]

    scenario "WALLETS_UTXO_01, WALLETS_UTXO_04 - UTxO statistics reflect wallet's activity" $ do
        fixture <- setup $ defaultSetup
            & initialCoins .~ [14, 42, 1337]

        response <- request $ Client.getUtxoStatistics
            $- (fixture ^. wallet . walletId)
        verify response
            [ expectWalletUTxO [14, 42, 1337]
            ]

    scenario "WALLETS_UTXO_04 - UTxO statistics reflect wallet's activity" $ do
        fixture <- setup $ defaultSetup
            & initialCoins .~ [13, 43, 66, 101, 1339]
        response <- request $ Client.getUtxoStatistics
            $- (fixture ^. wallet . walletId)
        verify response
            [ expectWalletUTxO [13, 43, 66, 101, 1339]
            ]

    -- Below are scenarios that are somewhat 'symmetric' for both 'create' and 'restore' operations.
    forM_ [CreateWallet, RestoreWallet] $ \operation -> describe (show operation) $ do
        scenario "WALLETS_CREATE_01 - One can create/restore previously deleted wallet" $ do
            fixture <- setup $ defaultSetup
                & initialCoins .~ [1000111]

            successfulRequest $ Client.deleteWallet
                $- (fixture ^. wallet . walletId)

            response <- request $ Client.postWallet $- NewWallet
                (fixture ^. backupPhrase)
                noSpendingPassword
                StrictAssurance
                kanjiPolishWalletName
                operation
            verify response
                [ expectWalletEventuallyRestored
                , expectFieldEqual walletName kanjiPolishWalletName
                , expectFieldEqual assuranceLevel StrictAssurance
                , expectFieldEqual hasSpendingPassword False
                , expectFieldEqual amount $ case operation of
                    RestoreWallet -> 1000111
                    CreateWallet  -> 0
                ]


        scenario "WALLETS_CREATE_02 - One can create/restore wallet without spending password" $ do
            fixture <- setup $ defaultSetup

            successfulRequest $ Client.deleteWallet
                $- (fixture ^. wallet . walletId)

            restoreResp <- request $ Client.postWallet $- NewWallet
                (fixture ^. backupPhrase)
                noSpendingPassword
                StrictAssurance
                kanjiPolishWalletName
                operation

            verify restoreResp
                [ expectWalletEventuallyRestored
                , expectFieldEqual walletName kanjiPolishWalletName
                , expectFieldEqual assuranceLevel StrictAssurance
                , expectFieldEqual hasSpendingPassword False
                ]


        scenario "WALLETS_CREATE_03 - One can create/restore wallet with spending password" $ do
            fixture <- setup $ defaultSetup
                & rawPassword .~ "patate"

            successfulRequest $ Client.deleteWallet
                $- (fixture ^. wallet . walletId)

            response <- request $ Client.postWallet $- NewWallet
                (fixture ^. backupPhrase)
                (Just $ fixture ^. spendingPassword)
                NormalAssurance
                "My HODL Wallet"
                operation

            verify (response :: Either ClientError Wallet)
                [ expectFieldEqual hasSpendingPassword True
                , expectFieldEqual walletName "My HODL Wallet"
                , expectFieldEqual assuranceLevel NormalAssurance
                ]


        describe "WALLETS_CREATE_04 - One cannot create/restore wallet if spending password is not hex-encoded string" $ do
            let matrix =
                    [ ( "spending password is less than 32 bytes / 64 characters"
                      , [json| "5416b2988745725998907addf4613c9b0764f04959030e1b81c6" |]
                      , [ expectJSONError "Error in $.spendingPassword: Expected spending password to be of either length 0 or 32, not 26" ]
                      )
                    , ( "spending password is more than 32 bytes / 64 characters"
                      , [json| "c0b75cebcd14403d7abba4227cea5b99b1b09148623cd927fa7bb40c6cca5583c" |]
                      , [ expectJSONError "Error in $.spendingPassword: suffix is not in base-16 format: c" ]
                      )
                    , ( "spending password is a number"
                      , [json| 541 |]
                      , [ expectJSONError "Error in $.spendingPassword: expected parseJSON failed for PassPhrase, encountered Number" ]
                      )
                    , ( "spending password is an empty string"
                      , [json| " " |]
                      , [ expectJSONError "Error in $.spendingPassword: suffix is not in base-16 format" ]
                      )
                    , ( "spending password is an array"
                      , [json| [] |]
                      , [ expectJSONError "Error in $.spendingPassword: expected parseJSON failed for PassPhrase, encountered Array" ]
                      )
                    , ( "spending password is an arbitrary utf-8 string"
                      , [json| "patate" |]
                      , [ expectJSONError "Error in $.spendingPassword: suffix is not in base-16 format" ]
                      ) -- ^ is an arbitrary string (not hex-encoded)
                    ]
            forM_ matrix $ \(title, password, expectations) -> scenario title $ do
                response <- unsafeRequest ("POST", "api/v1/wallets") $ Just $ [json|{
                    "operation": #{operation},
                    "backupPhrase": #{testBackupPhrase},
                    "assuranceLevel": "normal",
                    "name": "MyFirstWallet",
                    "spendingPassword": #{password}
                }|]
                verify (response :: Either ClientError Wallet) expectations


        scenario "WALLETS_CREATE_05 - One cannot create/restore wallet that already exists" $ do
            fixture <- setup $ defaultSetup

            response <- request $ Client.postWallet $- NewWallet
                (fixture ^. backupPhrase)
                noSpendingPassword
                defaultAssuranceLevel
                defaultWalletName
                CreateWallet

            verify response
                [ expectWalletError (WalletAlreadyExists (fixture ^. wallet . walletId))
                ]


        describe "WALLETS_CREATE_06 - One cannot create/restore wallet using less or more than 12 mnemonics which are valid BIP-39" $ do
            let matrix =
                    [ ( "less than 12 words"
                      , [json| #{mnemonicsWith9Words} |]
                      , [ expectJSONError "Invalid number of mnemonic words: got 9 words, expected 12 words" ]
                      )
                    , ( "more than 12 words"
                      , [json| #{mnemonicsWith15Words} |]
                      , [ expectJSONError "Invalid number of mnemonic words: got 15 words, expected 12 words" ]
                      )
                    , ("empty mnemonic"
                      , [json| [] |]
                      , [ expectJSONError "Invalid number of mnemonic words: got 0 words, expected 12 words" ]
                      )
                    ]
            forM_ matrix $ \(title, mnemonic, expectations) -> scenario title $ do
                response <- unsafeRequest ("POST", "api/v1/wallets") $ Just $ [json|{
                    "operation": #{operation},
                    "backupPhrase": #{mnemonic},
                    "assuranceLevel": "strict",
                    "name": #{russianWalletName},
                    "spendingPassword": "5416b2988745725998907addf4613c9b0764f04959030e1b81c603b920a115d0"
                }|]
                verify (response :: Either ClientError Wallet) expectations


        describe "WALLETS_CREATE_07 - One cannot create/restore wallet with invalid BIP-39 mnemonics" $ do
            let matrix =
                    [ ( "Kanji mnemonics / non-English mnemonics"
                      , [json| #{kanjiMnemonics} |]
                      , [ expectJSONError "Error in $.backupPhrase: MnemonicError: Invalid dictionary word:" ]
                      )
                    , ( "Invalid mnemonics"
                      , [json| #{invalidMnemonics} |]
                      , [ expectJSONError "Error in $.backupPhrase: MnemonicError: Invalid entropy checksum: got Checksum 11, expected Checksum 5" ]
                      )
                    ]
            forM_ matrix $ \(title, mnemonic, expectations) -> scenario title $ do
                response <- unsafeRequest ("POST", "api/v1/wallets") $ Just $ [json|{
                    "operation": #{operation},
                    "backupPhrase": #{mnemonic},
                    "assuranceLevel": "normal",
                    "name": #{russianWalletName},
                    "spendingPassword": "5416b2988745725998907addf4613c9b0764f04959030e1b81c603b920a115d0"
                }|]
                verify (response :: Either ClientError Wallet) expectations


        scenario "WALLET_CREATE_08 - One cannot create/restore wallet with mnemonics from the API doc" $ do
            response <- unsafeRequest ("POST", "api/v1/wallets") $ Just $ [json|{
                "operation": #{operation},
                "backupPhrase": #{apiDocsBackupPhrase},
                "assuranceLevel": "strict",
                "name": #{russianWalletName},
                "spendingPassword": "5416b2988745725998907addf4613c9b0764f04959030e1b81c603b920a115d0"
            }|]
            verify (response :: Either ClientError Wallet)
                [ expectJSONError "Error in $.backupPhrase: Forbidden Mnemonic: an example Mnemonic has been submitted. Please generate a fresh and private Mnemonic from a trusted source"
                ]


        describe "WALLETS_CREATE_09 - One cannot create/restore wallet with assurance level other than 'strict' or 'normal'" $ do
            let matrix =
                    [ ( "Arbitrary String"
                      , russianWalletName
                      , [ expectJSONError "Error in $.assuranceLevel: When parsing Bcc.Wallet.API.V1.Types.AssuranceLevel expected a String with the tag of a constructor but got" ]
                      )
                    , ( "Empty String"
                      , ""
                      , [ expectJSONError "Error in $.assuranceLevel: When parsing Bcc.Wallet.API.V1.Types.AssuranceLevel expected a String with the tag of a constructor but got" ]
                      )
                    ]
            forM_ matrix $ \(title, level, expectations) -> scenario title $ do
                response <- unsafeRequest ("POST", "api/v1/wallets") $ Just $ [json|{
                    "operation": #{operation},
                    "backupPhrase": #{testBackupPhrase},
                    "assuranceLevel": #{level},
                    "name": #{russianWalletName},
                    "spendingPassword": "5416b2988745725998907addf4613c9b0764f04959030e1b81c603b920a115d0"
                }|]
                verify (response :: Either ClientError Wallet) expectations


        describe "WALLETS_CREATE_10 - One cannot create/restore without all required parameters (operation)" $ do
            let matrix =
                    [ ( "Missing operation"
                      , [json|{
                            "backupPhrase": #{testBackupPhrase},
                            "assuranceLevel": "normal",
                            "name": "my hodl wallet",
                            "spendingPassword": "5416b2988745725998907addf4613c9b0764f04959030e1b81c603b920a115d0"
                        }|]
                      , [ expectJSONError "When parsing the record newWallet of type Bcc.Wallet.API.V1.Types.NewWallet the key operation was not present." ]
                      )
                    , ( "Missing backupPhrase"
                      , [json|{
                            "operation": #{operation},
                            "assuranceLevel": "normal",
                            "name": "my hodl wallet",
                            "spendingPassword": "5416b2988745725998907addf4613c9b0764f04959030e1b81c603b920a115d0"
                        }|]
                      , [ expectJSONError "When parsing the record newWallet of type Bcc.Wallet.API.V1.Types.NewWallet the key backupPhrase was not present." ]
                      )
                    , ( "Missing assuranceLevel"
                      , [json|{
                            "operation": #{operation},
                            "backupPhrase": #{testBackupPhrase},
                            "name": "my hodl wallet",
                            "spendingPassword": "5416b2988745725998907addf4613c9b0764f04959030e1b81c603b920a115d0"
                        }|]
                      , [ expectJSONError "When parsing the record newWallet of type Bcc.Wallet.API.V1.Types.NewWallet the key assuranceLevel was not present." ]
                      )
                    , ( "Missing name"
                      , [json|{
                            "operation": #{operation},
                            "backupPhrase": #{testBackupPhrase},
                            "assuranceLevel": "normal",
                            "spendingPassword": "5416b2988745725998907addf4613c9b0764f04959030e1b81c603b920a115d0"
                        }|]
                      , [ expectJSONError "When parsing the record newWallet of type Bcc.Wallet.API.V1.Types.NewWallet the key name was not present." ]
                      )
                    ]
            forM_ matrix $ \(title, body, expectations) -> scenario title $ do
                response <- unsafeRequest ("POST", "api/v1/wallets") $ Just body
                verify (response :: Either ClientError Wallet) expectations


        describe "WALLETS_CREATE_11 - One can create/restore wallet with name of any length" $ do
            let matrix =
                    [ ("long wallet name", longWalletName)
                    , ("empty name", "")
                    ]
            forM_ matrix $ \(title, name) -> scenario title $ do
                fixture <- setup $ defaultSetup
                    & walletName .~ name
                response <- request $ Client.getWallet
                    $- (fixture ^. wallet . walletId)
                verify response
                    [ expectFieldEqual walletName name
                    ]

    describe "WALLETS_CREATE_12 - Cannot perform operation other than 'create' or 'restore'" $ do
        let matrix =
                [ ( "Invalid operation name"
                  , [json| #{russianWalletName} |]
                  , [ expectJSONError "Error in $.operation: When parsing Bcc.Wallet.API.V1.Types.WalletOperation expected a String with the tag of a constructor but got" ]
                  )
                , ( "Empty operation name"
                  , [json| "" |]
                  , [ expectJSONError "Error in $.operation: When parsing Bcc.Wallet.API.V1.Types.WalletOperation expected a String with the tag of a constructor but got" ]
                  )
                ]
        forM_ matrix $ \(title, operation, expectations) -> scenario title $ do
            response <- unsafeRequest ("POST", "api/v1/wallets") $ Just $ [json|{
                "operation": #{operation},
                "backupPhrase": #{testBackupPhrase},
                "assuranceLevel": "normal",
                "name": #{russianWalletName},
                "spendingPassword": "5416b2988745725998907addf4613c9b0764f04959030e1b81c603b920a115d0"
            }|]
            verify (response :: Either ClientError Wallet) expectations
  where

    testBackupPhrase :: [Text]
    testBackupPhrase =
        ["clap", "panda", "slim", "laundry", "more", "vintage", "cash", "shaft"
        , "token", "history", "misery", "problem"]

    apiDocsBackupPhrase :: [Text]
    apiDocsBackupPhrase =
        ["squirrel", "material", "silly", "twice", "direct", "slush", "pistol", "razor"
         , "become", "junk", "kingdom", "flee"]

    invalidMnemonics :: [Text]
    invalidMnemonics =
        ["clinic","nuclear","paddle","leg","lounge","fabric","claw","trick"
        ,"divide","pretty","argue","master"]

    kanjiMnemonics :: [Text]
    kanjiMnemonics =
        ["?????????", "????????????", "?????????",???"?????????",???"????????????",???"????????????",???"???????????????"
        ,???"??????????????????",???"????????????",???"????????????",???"???????????????",???"?????????"]

    mnemonicsWith9Words :: [Text]
    mnemonicsWith9Words =
        ["pave", "behind", "simple", "lobster", "digital", "ready", "switch"
        , "uncle", "dragon"]

    mnemonicsWith15Words :: [Text]
    mnemonicsWith15Words =
        ["organ", "uniform", "anchor", "exhibit", "satisfy", "scrub", "vacant"
        , "hold", "spawn", "super", "tenant", "change", "illegal", "yard", "quarter"]

    kanjiPolishWalletName :: Text
    kanjiPolishWalletName = "???????????????????????????????????????????????? ?????????????????????????????????????????????????????????????????????????????? ?????????????????????????????????\n????????????????????????????????????????????????????????? ??????????????????????????????????????????????????? ??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????\n??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????? ??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????? ???????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????\r\n???????????????????????????????????????????????????????????????????????????\n????????????????????????????????????????????????? ?????? ???????????????????????????????????????????????????????????????????????????????????????????????????????????????????? ??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????? ??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????? ?????????????????????????????????\n??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????? ???????????????????????????????????????????????????????????????????????????????????????????????? ???????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????? ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????"

    longWalletName :: Text
    longWalletName = mconcat $ replicate 1000 kanjiPolishWalletName

    russianWalletName :: Text
    russianWalletName = "????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????"
