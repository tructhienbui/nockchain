/=  dk  /apps/dumbnet/lib/types
/=  sp  /common/stark/prover
/=  dumb-transact  /common/tx-engine
/=  *  /common/zoon
::
:: everything to do with mining and mining state
::
|_  [m=mining-state:dk =blockchain-constants:dumb-transact]
+*  t  ~(. dumb-transact blockchain-constants)
+|  %admin
::  +set-mining: set .mining
++  set-mining
  |=  mine=?
  ^-  mining-state:dk
  m(mining mine)
::
::  +set-pubkey: set .pubkey
++  set-pubkeys
  |=  pks=(list lock:t)
  ^-  mining-state:dk
  =.  pubkeys.m
    (~(gas z-in *(z-set lock:t)) pks)
  m
::
::  +set-shares validate and set .shares
++  set-shares
  |=  shr=(list [lock:t @])
  =/  s=shares:t  (~(gas z-by *(z-map lock:t @)) shr)
  ?.  (validate:shares:t s)
    ~|('invalid shares' !!)
  m(shares s)
::
+|  %candidate-block
++  set-pow
  |=  prf=proof:sp
  ^-  mining-state:dk
  m(pow.candidate-block (some prf))
::
++  set-digest
  ^-  mining-state:dk
  m(digest.candidate-block (compute-digest:page:t candidate-block.m))
::
++  update-timestamp
  |=  now=@da
  ^-  mining-state:dk
  ?:  |(=(*page:t candidate-block.m) !mining.m)
    m
  ?:  %+  gte  timestamp.candidate-block.m
      (time-in-secs:page:t (sub now update-candidate-timestamp-interval:t))
    m
  =.  timestamp.candidate-block.m  (time-in-secs:page:t now)
  m
::
++  heard-new-tx
  |=  raw=raw-tx:t
  ^-  mining-state:dk
  ~>  %slog.[1 'miner: heard-new-tx']
  ::
  :: skip if no mining pubkey
  ?:  =(*(z-set lock:t) pubkeys.m)  m
  :: select txs sorted by fee-per-byte
  =/  txs-list  (list raw-tx:t)
    (sort
      |=(a b)
        ?:  (gth (div fee.a size.a) (div fee.b size.b))  %.y  %.n
      (cons raw ~))
  =/  tx=(unit tx:t)  (mole |.((new:tx:t (head txs-list) height.candidate-block.m)))
  ?~  tx
    m
  =/  new-acc=(unit tx-acc:t)
    (process:tx-acc:t candidate-acc.m u.tx height.candidate-block.m)
  ?~  new-acc
    m
  :: add tx id
  =.  tx-ids.candidate-block.m
    (~(put z-in tx-ids.candidate-block.m) id.raw)
  =/  old-fees=coins:t  fees.candidate-acc.m
  =.  candidate-acc.m  u.new-acc
  =/  new-fees=coins:t  fees.candidate-acc.m
  ?:  =(new-fees old-fees)
    m
  ?>  (gth new-fees old-fees)
  =/  fee-diff=coins:t  (sub new-fees old-fees)
  =/  old-assets=coins:t
    %+  roll  ~(val z-by coinbase.candidate-block.m)
    |=  [c=coins:t sum=coins:t]
    (add c sum)
  =/  new-assets=coins:t  (add old-assets fee-diff)
  =.  coinbase.candidate-block.m
    (new:coinbase-split:t new-assets shares.m)
  m
::
++  heard-new-block
  |=  [c=consensus-state:dk p=pending-state:dk now=@da]
  ^-  mining-state:dk
  :: only regenerate candidate block if parent or tx set changed
  ?~  heaviest-block.c
    ~>  %slog.[0 leaf+"no genesis block"]
    m
  ?:  =(u.heaviest-block.c parent.candidate-block.m)
    m
  ?:  =(*(z-set lock:t) pubkeys.m)
    m
  =.  candidate-block.m
    %-  new-candidate:page:t
    :*  (to-page:local-page:t (~(got z-by blocks.c) u.heaviest-block.c))
        now
        (~(got z-by targets.c) u.heaviest-block.c)
        shares.m
    ==
  =.  candidate-acc.m
    (new:tx-acc:t (~(get z-by balance.c) u.heaviest-block.c))
  %+  roll  ~(val z-by raw-txs.p)
  |=  [raw=raw-tx:t min=_m]
  (heard-new-tx raw)
--