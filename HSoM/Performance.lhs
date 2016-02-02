> {-#  LANGUAGE FlexibleInstances, TypeSynonymInstances  #-}
> module HSoM.Performance where
> import Euterpea

From Euterpea we have:

type Performance = [MEvent]

data MEvent = MEvent {  eTime    :: PTime, 
                      eInst    :: InstrumentName, 
                      ePitch   :: AbsPitch,
                      eDur     :: DurT, 
                      eVol     :: Volume, 
                      eParams  :: [Double]}
     deriving (Show,Eq,Ord)

type PTime     = Rational
type DurT      = Rational

merge :: Performance -> Performance -> Performance
merge []          es2         =  es2
merge es1         []          =  es1
merge a@(e1:es1)  b@(e2:es2)  =  
  if eTime e1 < eTime e2  then  e1  : merge es1 b
                          else  e2  : merge a es2


> data Context a = Context {  cTime    :: PTime, 
>                             cPlayer  :: Player a, 
>                             cInst    :: InstrumentName, 
>                             cDur     :: DurT, 
>                             cPch     :: AbsPitch,
>                             cVol     :: Volume,
>                             cKey     :: (PitchClass, Mode) }
>      deriving Show

> metro              :: Int -> Dur -> DurT
> metro setting dur  = 60 / (fromIntegral setting * dur)

> type PMap a  = PlayerName -> Player a

> hsomPerform :: PMap a -> Context a -> Music a -> Performance
> hsomPerform pm c m = fst (perf pm c m)

> perf :: PMap a -> Context a -> Music a -> (Performance, DurT)
> perf pm 
>   c@Context {cTime = t, cPlayer = pl, cDur = dt, cPch = k} m =
>   case m of
>      Prim (Note d p)            -> (playNote pl c d p, d*dt)
>      Prim (Rest d)              -> ([], d*dt)
>      m1 :+: m2                  ->  
>              let  (pf1,d1)  = perf pm c m1
>                   (pf2,d2)  = perf pm (c {cTime = t+d1}) m2
>              in (pf1++pf2, d1+d2)
>      m1 :=: m2                  -> 
>              let  (pf1,d1)  = perf pm c m1
>                   (pf2,d2)  = perf pm c m2
>              in (merge pf1 pf2, max d1 d2)
>      Modify  (Tempo r)       m  -> perf pm (c {cDur = dt / r})    m
>      Modify  (Transpose p)   m  -> perf pm (c {cPch = k + p})     m
>      Modify  (Instrument i)  m  -> perf pm (c {cInst = i})        m
>      Modify  (KeySig pc mo)  m  -> perf pm (c {cKey = (pc,mo)})   m
>      Modify  (Phrase pas)    m  -> interpPhrase pl pm c pas       m
>      Modify  (Custom s)     m  -> 
>          if take 7 s == "Player " then perf pm (c {cPlayer = pm $ drop 7 s})  m
>          else perf pm c m

> type PlayerName = String

> data Player a = MkPlayer {  pName         :: PlayerName, 
>                             playNote      :: NoteFun a,
>                             interpPhrase  :: PhraseFun a}

> type NoteFun a    =  Context a -> Dur -> a -> Performance
> type PhraseFun a  =  PMap a -> Context a -> [PhraseAttribute]
>                      -> Music a -> (Performance, DurT)

> instance Show a => Show (Player a) where
>    show p = pName p

> defPlayer  :: Player Note1
> defPlayer  = MkPlayer 
>              {  pName         = "Default",
>                 playNote      = defPlayNote      defNasHandler,
>                 interpPhrase  = defInterpPhrase  defPasHandler}

> defPlayNote ::  (Context (Pitch,[a]) -> a -> MEvent-> MEvent)
>                 -> NoteFun (Pitch, [a])
> defPlayNote nasHandler 
>   c@(Context cTime cPlayer cInst cDur cPch cVol cKey) d (p,nas) =
>     let initEv = MEvent {  eTime    = cTime,     eInst  = cInst,
>                           eDur     = d * cDur,  eVol = cVol,
>                           ePitch   = absPitch p + cPch,
>                           eParams  = [] }
>     in [ foldr (nasHandler c) initEv nas ]

> defNasHandler :: Context a -> NoteAttribute -> MEvent -> MEvent
> defNasHandler c (Volume v)     ev = ev {eVol = v}
> defNasHandler c (Params pms)   ev = ev {eParams = pms}
> defNasHandler _            _   ev = ev

> defInterpPhrase :: 
>    (PhraseAttribute -> Performance -> Performance) -> 
>    (  PMap a -> Context a -> [PhraseAttribute] ->  -- PhraseFun
>       Music a -> (Performance, DurT) )
> defInterpPhrase pasHandler pm context pas m =
>        let (pf,dur) = perf pm context m
>        in (foldr pasHandler pf pas, dur)

> defPasHandler :: PhraseAttribute -> Performance -> Performance
> defPasHandler (Dyn (Accent x))    = 
>     map (\e -> e {eVol = round (x * fromIntegral (eVol e))})
> defPasHandler (Art (Staccato x))  = 
>     map (\e -> e {eDur = x * eDur e})
> defPasHandler (Art (Legato   x))  = 
>     map (\e -> e {eDur = x * eDur e})
> defPasHandler _                   = id


> defPMap "Fancy"    = fancyPlayer
> defPMap "Default"  = defPlayer
> defPMap n          = defPlayer { pName = n }

> defCon  :: Context Note1
> defCon  = Context {  cTime    = 0,
>                      cPlayer  = fancyPlayer,
>                      cInst    = AcousticGrandPiano,
>                      cDur     = metro 120 qn,
>                      cPch     = 0,
>                      cKey     = (C, Major),
>                      cVol     = 127 }

> fancyPlayer :: Player (Pitch, [NoteAttribute])
> fancyPlayer  = MkPlayer {  pName         = "Fancy",
>                            playNote      = defPlayNote defNasHandler,
>                            interpPhrase  = fancyInterpPhrase}

> fancyInterpPhrase             :: PhraseFun a
> fancyInterpPhrase pm c [] m   = perf pm c m
> fancyInterpPhrase pm 
>   c@Context {  cTime = t, cPlayer = pl, cInst = i, 
>                cDur = dt, cPch = k, cVol = v}
>   (pa:pas) m =
>   let  pfd@(pf,dur)  =  fancyInterpPhrase pm c pas m
>        loud x        =  fancyInterpPhrase pm c (Dyn (Loudness x) : pas) m
>        stretch x     =  let  t0 = eTime (head pf);  r  = x/dur
>                              upd (e@MEvent {eTime = t, eDur = d}) = 
>                                let  dt  = t-t0
>                                     t'  = (1+dt*r)*dt + t0
>                                     d'  = (1+(2*dt+d)*r)*d
>                                in e {eTime = t', eDur = d'}
>                         in (map upd pf, (1+x)*dur)
>        inflate x     =  let  t0  = eTime (head pf);  
>                              r   = x/dur
>                              upd (e@MEvent {eTime = t, eVol = v}) = 
>                                  e {eVol =  round ( (1+(t-t0)*r) * 
>                                             fromIntegral v)}
>                         in (map upd pf, dur)
>   in case pa of
>     Dyn (Accent x) ->
>         ( map (\e-> e {eVol = round (x * fromIntegral (eVol e))}) pf, dur)
>     Dyn (StdLoudness l) -> 
>         case l of 
>            PPP  -> loud 40;       PP -> loud 50;   P    -> loud 60
>            MP   -> loud 70;       SF -> loud 80;   MF   -> loud 90
>            NF   -> loud 100;      FF -> loud 110;  FFF  -> loud 120
>     Dyn (Loudness x)     ->  fancyInterpPhrase pm
>                              c{cVol = round x} pas m
>     Dyn (Crescendo x)    ->  inflate   x ; Dyn (Diminuendo x)  -> inflate (-x)
>     Tmp (Ritardando x)   ->  stretch   x ; Tmp (Accelerando x) -> stretch (-x)
>     Art (Staccato x)     ->  (map (\e-> e {eDur = x * eDur e}) pf, dur)
>     Art (Legato x)       ->  (map (\e-> e {eDur = x * eDur e}) pf, dur)
>     Art (Slurred x)      -> 
>         let  lastStartTime  = foldr (\e t -> max (eTime e) t) 0 pf
>              setDur e       =   if eTime e < lastStartTime
>                                 then e {eDur = x * eDur e}
>                                 else e
>         in (map setDur pf, dur) 
>     Art _                -> pfd
>     Orn _                -> pfd

> class Performable a where
>   perfDur :: PMap Note1 -> Context Note1 -> Music a -> (Performance, DurT)

> instance Performable Note1 where
>   perfDur pm c m = perf pm c m

> instance Performable Pitch where
>   perfDur pm c = perfDur pm c . toMusic1

> instance Performable (Pitch, Volume) where
>   perfDur pm c = perfDur pm c . toMusic1

> defToPerf :: Performable a => Music a -> Performance
> defToPerf = fst . perfDur defPMap defCon

> toPerf :: Performable a => PMap Note1 -> Context Note1 -> Music a -> Performance
> toPerf pm con = fst . perfDur pm con

> playA myPMap myCon = playC defParams{perfAlg=hsomPerform myPMap myCon}
> writeMidiA fn myPMap myCon = exportMidiFile fn . toMidi . hsomPerform myPMap myCon
