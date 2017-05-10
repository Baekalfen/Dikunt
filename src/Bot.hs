module Bot
    ( connect
    , disconnect
    , loop
    ) where

import qualified BotTypes as BT
import Monitoring (Monitor(..), startMonitoring, inputHandle)
import Control.Concurrent (forkIO, readMVar, threadDelay)
import Control.Exception (catch, IOException)
import Control.Monad (forever)
import IRCParser.IRCMessageParser (parseMessage)
import IRCWriter.IRCWriter (writeMessage)
import Network (connectTo, PortID(..))
import Safe (readMay)
import System.IO
    ( hClose
    , hSetBuffering
    , hGetLine
    , BufferMode(..)
    , hPrint
    , Handle
    , hPutStrLn
    , stderr
    )
import Text.Printf (hPrintf)

disconnect :: BT.Bot -> IO ()
disconnect = hClose . BT.socket

{- | Connect the bot to an IRC server with the channel, nick, pass and port
 - given. -}
connect :: String
    -- ^ URL to server to connect to.
    -> String
    -- ^ Channel name to join.
    -> String
    -- ^ Nickname to use.
    -> String
    -- ^ Password to connect with.
    -> Integer
    -- ^ Port to use.
    -> [FilePath]
    -- ^ Plugins to load.
    -> IO BT.Bot
connect serv chan nick pass port execs = do
    h <- connectTo serv (PortNumber (fromIntegral port))
    hSetBuffering h NoBuffering

    monitor <- startMonitoring execs [nick, chan]
    let bot = BT.bot h nick chan pass monitor

    -- Start thread responding.
    _ <- forkIO $ respond bot

    return bot

loop :: BT.Bot -> IO ()
loop bot@(BT.Bot h nick chan pass _) = do
    write h $ BT.ClientNick nick
    write h $ BT.ClientUser nick 0 "DikuntBot"
    write h $ BT.ClientPrivMsg (BT.IRCUser "NickServ" Nothing Nothing)
        ("IDENTIFY " ++ nick ++ " " ++ pass)
    write h $ BT.ClientJoin [(chan, "")]

    listen bot

listen :: BT.Bot -> IO ()
listen (BT.Bot h _ _ _ pluginHandles) = forever $ do
    s <- hGetLine h
    Monitor processes _ <- readMVar pluginHandles
    let ins = map inputHandle processes

    case parseMessage (s ++ "\n") of
        Just (BT.ServerPing from) -> write h $ BT.ClientPong from
        Just message -> mapM_ (safePrint message) ins
        Nothing -> hPutStrLn stderr $ "Could not parse message \"" ++ s ++ "\""
  where
    safePrint msg processHandle = catch (hPrint processHandle msg) (\e -> do
        let err = show (e :: IOException)
        hPutStrLn stderr err)

respond :: BT.Bot -> IO ()
respond (BT.Bot h _ chan _ monitor) = forever $ do
    Monitor _ (output, _) <- readMVar monitor

    line <- hGetLine output
    case readMay line :: Maybe BT.ClientMessage of
        Just message -> write h message
        Nothing -> write h $ BT.ClientPrivMsgChan chan line

    threadDelay 1000000

write :: Handle -> BT.ClientMessage -> IO ()
write h mes = hPrintf h $ writeMessage mes
