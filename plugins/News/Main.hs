module Main (main) where

import qualified BotTypes as BT
import Control.Error.Util (note)
import Control.Monad (forever)
import Network.Download (openAsFeed)
import Safe (readMay)
import System.Environment (getArgs)
import System.IO (stdout, stdin, hSetBuffering, BufferMode(..))
import Text.Feed.Query
    ( feedItems
    , getItemTitle
    , getItemLink
    , getItemDescription
    )
import Text.Feed.Types (Item)
import Text.Regex.PCRE ((=~))

main :: IO ()
main = do
    [nick, _] <- getArgs

    hSetBuffering stdout LineBuffering
    hSetBuffering stdin LineBuffering

    forever $ do
        line <- getLine
        handleMessage (readMay line :: Maybe BT.ServerMessage) nick

handleMessage :: Maybe BT.ServerMessage -> String -> IO ()
handleMessage (Just (BT.ServerPrivMsg BT.IRCUser{} _ msg)) nick
    | msg =~ helpPattern = help nick
    | msg =~ runPattern = giveNews
    | otherwise = return ()
  where
    helpPattern = concat ["^", sp, nick, ":", ps, "news", ps, "help", sp, "$"]
    runPattern = concat ["^", sp, nick, ":", ps, "news", sp, "$"]
    sp = "[ \\t]*"
    ps = "[ \\t]+"
handleMessage _ _ = return ()

help :: String -> IO ()
help nick = do
    putStrLn $ nick ++ ": news help - Display this help message"
    putStrLn $ nick ++ ": news - Display news"

giveNews :: IO ()
giveNews = do
    feed <- openAsFeed rssFeed
    either putStrLn putStrLn (giveNews' feed)
  where
    giveNews' f = do
        f' <- f
        note "Feed analysis failed" $ analyseFeed (feedItems f')

analyseFeed :: [Item] -> Maybe String
analyseFeed [] = Nothing
analyseFeed (item:_) = do
    title <- getItemTitle item
    link <- getItemLink item
    description <- getItemDescription item

    return $ title ++ "\n    " ++ description ++ "\n" ++ link

rssFeed :: String
rssFeed = "http://feeds.bbci.co.uk/news/world/rss.xml"