module Main where

import qualified Parsers.Tests
import qualified Types.Internal.ChannelTest
import qualified Types.Internal.HostnameTest
import qualified Types.Internal.IRCUserTest
import qualified Types.Internal.MessageTest
import qualified Tests
import Test.Tasty
    ( TestTree
    , testGroup
    , defaultMain
    )

allTests :: TestTree
allTests = testGroup "Tasty Tests"
    [ Tests.tests
    , Parsers.Tests.tests
    , Types.Internal.ChannelTest.tests
    , Types.Internal.HostnameTest.tests
    , Types.Internal.IRCUserTest.tests
    , Types.Internal.MessageTest.tests
    ]

main :: IO ()
main = defaultMain allTests
