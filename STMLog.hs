-- Originally from Control.Sequential.STM
--
--
-- Transactional memory for sequential implementations.
-- Transactions do not run concurrently, but are atomic in the face
-- of exceptions.

{-# LANGUAGE CPP #-}

#if __GLASGOW_HASKELL__ >= 701
{-# LANGUAGE Trustworthy #-}
#endif

-- #hide
module STMLog (
STM, --atomically, throwSTM, catchSTM,
--TVar, newTVar, newTVarIO, readTVar, readTVarIO, writeTVar
    ) where

#if __GLASGOW_HASKELL__ < 705
import Prelude hiding (catch)
#endif
import Control.Applicative (Applicative(pure, (<*>)))
import Control.Exception
import Data.IORef
import RG

{-@ predicate Delta x y = 1 > 0 @-}
-- The reference contains a rollback action to be executed on exceptions
{- data STM a = STM (stm_log_ref :: (RGRef (IO ()) <{\_ -> True}, {\x y -> (x = y) or (exists f, y = f >> x)}> -> IO a)) -}
{-@ data STM a = STM (stm_log_ref :: (RGRef<{\ x -> 1 > 0},{\ x y -> 1 > 0}> (IO ()) -> IO a)) @-}
data STM a = STM (RGRef (IO ()) -> IO a)
-- STM should be a newtype, but I can't figure out how to make LH refine newtypes

{- unSTM :: STM a -> RGRef<{\ x -> 1 > 0},{\ x y -> 1 > 0}> (IO ()) -> IO a @-}
--unSTM :: STM a -> RGRef (IO ()) -> IO a
--unSTM (STM f) = f

--instance Functor STM where
--    fmap f (STM m) = STM (fmap f . m)
--
--instance Applicative STM where
--    pure = STM . const . pure
--    STM mf <*> STM mx = STM $ \ r -> mf r <*> mx r
--
--instance Monad STM where
--    return = pure
--    STM m >>= k = STM $ \ r -> do
--                                x <- m r
--                                unSTM (k x) r
--
--atomically :: STM a -> IO a
--atomically (STM m) = do
--                        r <- newRGRef (return ()) (return ()) (\ x y -> y) -- actually, rely is not reflexive
--                        m r `onException` do
--                                            rollback <- readRGRef r
--                                            rollback
--
--throwSTM :: Exception e => e -> STM a
--throwSTM = STM . const . throwIO
--
--catchSTM :: Exception e => STM a -> (e -> STM a) -> STM a
--catchSTM (STM m) h = STM $ \ r -> do
--    --old_rollback <- readIORef r
--    --writeIORef r (return ())
--    --r2 <- newIORef (return ())
--    r2 <- newRGRef (return ()) (return ()) (\ x y -> y) -- actually, rely is not reflexive
--    --res <- try (m r)
--    res <- try (m r2)
--    rollback_m <- readRGRef r2
--    --rollback_m <- readIORef r
--    case res of
--        Left ex -> do
--                        rollback_m
--                        --writeIORef r old_rollback
--                        unSTM (h ex) r
--        Right a -> do
--                        --writeIORef r (rollback_m >> old_rollback)
--                        modifyRGRef r (\ old_rollback -> (rollback_m >> old_rollback)) (\ x y -> y)
--                        return a
--
newtype TVar a = TVar (IORef a)
    deriving (Eq)

--newTVar :: a -> STM (TVar a)
--newTVar a = STM (const (newTVarIO a))
--
newTVarIO :: a -> IO (TVar a)
newTVarIO a = do
    ref <- newIORef a
    return (TVar ref)
--
--readTVar :: TVar a -> STM a
--readTVar (TVar ref) = STM (const (readIORef ref))
--
readTVarIO :: TVar a -> IO a
readTVarIO (TVar ref) = readIORef ref
--
--writeTVar :: TVar a -> a -> STM ()
--writeTVar (TVar ref) a = STM $ \ r -> do
--    oldval <- readIORef ref
--    modifyRGRef r (writeIORef ref oldval >>) (\x y -> y)
--    writeIORef ref a
