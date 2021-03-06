module Main (main) where

import qualified Types.BotTypes as BT
import Control.Monad (forever)
import Control.Monad.State.Strict (runStateT, StateT, get, lift, put)
import Data.Aeson (decode)
import Data.List.Utils (replace)
import qualified Data.Text.Lazy.Encoding as T
import qualified Data.Text.Lazy.IO as T
import System.Environment (getArgs)
import System.IO (stdout, stdin, hSetBuffering, BufferMode(..))
import Text.Regex.PCRE ((=~))

main :: IO ()
main = do
    (nick:_) <- getArgs

    hSetBuffering stdout LineBuffering
    hSetBuffering stdin LineBuffering

    _ <- runStateT (forever $ do
        line <- lift T.getLine
        handleInput nick $ (decode . T.encodeUtf8) line) ""

    return ()

handleInput :: String -> Maybe BT.ServerMessage -> StateT String IO ()
handleInput nick (Just (BT.ServerPrivMsg _ _ msg))
    | str =~ helpPattern = lift $ help nick
    | [[_, old, new]] <- str =~ runPattern = do
        m <- get
        lift $ putStrLn (replace old new m)
    | otherwise = put str
  where
    str = BT.getMessage msg
    helpPattern = concat ["^", sp, nick, ":", ps, "fix", ps, "help", sp]
    runPattern = concat ["^", sp, "s/([a-zA-Z0-9 ]*)/([a-zA-Z0-9 ]*)", sp, "$"]
    sp = "[ \\t]*"
    ps = "[ \\t]+"
handleInput _ _ = return ()

help :: String -> IO ()
help nick = putStrLn $ unlines
    [ nick ++ ": fix help - Display this message"
    , "s/<old>/<new> - Replace <old> with <new> in latest message"
    ]
