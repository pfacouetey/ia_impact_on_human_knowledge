; ================================
; BREEDS AND GLOBALS
; ================================

breed [persons person]
undirected-link-breed [person-links person-link] ; Social network links

persons-own [
  education-level         ; Integer (1-3)
  decision-making-level   ; Continuous (0-1)
  privacy-level           ; Continuous (0-1)
  has-job?
  assigned-job
  knowledge
]

patches-own [
  job?
  job-education-level     ; Integer (1-3)
  job-ai-usage-level      ; Continuous (0-1)
  desirability            ; For spatial migration
  ai-adjustment-speed     ; For adaptive job market
]

globals [
  tax-rate                ; For policy intervention
  ubi                     ; Universal Basic Income
]

; ================================
; SETUP
; ================================

to setup
  clear-all
  validate-parameters
  setup-persons
  setup-social-network
  reset-ticks
end

; ================================
; PARAMETER VALIDATION
; ================================

to validate-parameters
  if (Probability_education1 < 0) or (Probability_education1 > 1) [
    user-message "Probability_education1 must be between 0 and 1"
    stop
  ]
  if (Probability_education2 < 0) or (Probability_education2 > 1) [
    user-message "Probability_education2 must be between 0 and 1"
    stop
  ]
  if (Probability_education1 + Probability_education2) > 1 [
    user-message "Sum of education probabilities must not exceed 1"
    stop
  ]
  if (Min_jobs < 0) [
    user-message "Min_jobs must be ≥ 0"
    stop
  ]
  if (Max_jobs < Min_jobs) [
    user-message "Max_jobs must be ≥ Min_jobs"
    stop
  ]
end

; ================================
; MAIN SIMULATION LOOP
; ================================

to go
  if ticks >= Max_time [ stop ]
  delete-jobs
  create-jobs
  assign-jobs
  ;; Randomize whether creation or death happens first
  ifelse (random 2 = 0) [
    create-new-persons
    remove-dead-persons
  ] [
    remove-dead-persons
    create-new-persons
  ]
  update-knowledge
  adapt-ai-usage
  implement-policy
  calculate-desirability
  migrate-persons
  update-ai-adoption
  reproduce
  update-decisions
  tick
end

; ================================
; PERSON PROCEDURES
; ================================

to setup-persons
  create-persons N_persons [
    setup-person
    set knowledge (decision-making-level * education-level)
  ]
end

to setup-person  ; Person initialization helper
  set color blue
  set shape "person"
  setxy random-pxcor random-pycor
  set education-level calculate-education-level
  set decision-making-level random-float 1
  set privacy-level random-float 1
  set has-job? false
  set assigned-job nobody
end

; SOCIAL NETWORK DYNAMICS
to setup-social-network
  ask persons [
    let n random 3 + 1
    let others other persons with [not link-neighbor? myself]
    if any? others [
      create-person-links-with n-of (min list n count others) others
    ]
  ]
  ask person-links [ set color gray set thickness 0.2 ]
end

; MULTI-GENERATIONAL SYSTEM (reproduction)
to reproduce
  ask persons [
    if random-float 1 < 0.01 * (1 - privacy-level) [
      hatch 1 [
        set education-level max list 1 ([education-level] of myself - 1)
        set knowledge knowledge * 0.7
        set decision-making-level random-float 1
        set privacy-level random-float 1
        set has-job? false
        set assigned-job nobody
        set color blue
      ]
    ]
  ]
end

to create-new-persons
  let current-pop count persons
  let num-to-create floor (Population_max_increase_per_tick * current-pop)
  if num-to-create > 0 [
    create-persons num-to-create [
      setup-person
      set knowledge (decision-making-level * education-level)
    ]
  ]
end

to remove-dead-persons
  ask persons [
    let death-chance Population_max_death_per_tick
    ; POLICY: Reduce death chance for low-education with UBI
    if education-level = 1 [ set death-chance death-chance - ubi ]
    if random-float 1 < death-chance [
      if has-job? and assigned-job != nobody [
        set has-job? false
        set assigned-job nobody
      ]
      die
    ]
  ]
end

to-report calculate-education-level ; Education level distribution
  let r random-float 1
  ifelse r <= Probability_education1 [
    report 1
  ] [
    ifelse r <= (Probability_education1 + Probability_education2) [
      report 2
    ] [
      report 3
    ]
  ]
end

; ================================
; KNOWLEDGE & SOCIAL TRANSFER
; ================================

to update-knowledge
  ask persons [
    if has-job? [
      let ai [job-ai-usage-level] of assigned-job
      update-knowledge-growth ai
      attempt-skill-decay ai
      ; SKILL TRANSFER SYSTEM: Social knowledge sharing
      ask person-link-neighbors [
        if random-float 1 < 0.2 [
          set knowledge (knowledge + [knowledge] of myself) / 2
        ]
      ]
    ]
  ]
end

to update-knowledge-growth [ai]
  set knowledge knowledge + (ai * education-level)
end

to attempt-skill-decay [ai]
  let skills-decay-probability random-float 1
  if (skills-decay-probability > Skills_decay_threshold) [
    set education-level max (list 1 (education-level - 1))
    set knowledge knowledge * 0.9
  ]
end

; ================================
; JOB MARKET SYSTEM
; ================================

to create-jobs
  let target-jobs Min_jobs + random (Max_jobs - Min_jobs + 1)
  let candidates patches with [not job?]
  ask n-of (min (list target-jobs (count candidates))) candidates [
    set job? true
    set pcolor orange
    set job-education-level 1 + random 2  ; Int 1-3
    set job-ai-usage-level 0.1 + random-float 0.8  ; 0.1-0.9
    set ai-adjustment-speed 0.05 ; Adaptive job market speed
  ]
end

to delete-jobs
  ask patches [ if not is-boolean? job? [ set job? false ] ]
  let existing-jobs patches with [job?]
  let to-delete n-of (count existing-jobs * Clearance_rate) existing-jobs
  ask to-delete [
    set job? false
    set pcolor black
  ]
  free-associated-workers to-delete
end

to free-associated-workers [deleted-jobs]
  ask persons [
    if assigned-job != nobody [
      if member? assigned-job deleted-jobs [
        set has-job? false
        set assigned-job nobody
        set color blue
      ]
    ]
  ]
end

to assign-jobs
  let candidates persons with [not has-job?]
  ask candidates [
    let suitable-jobs patches with [
      job? and (job-education-level <= [education-level] of myself)
    ]
    if any? suitable-jobs [
      let job one-of suitable-jobs
      accept-job job
    ]
  ]
end

to accept-job [job]
  set has-job? true
  set assigned-job job
  set color green
  let ai [job-ai-usage-level] of job
  set decision-making-level (1 - ai)
  set privacy-level max (list 0 (privacy-level - (Laziness_factor * ai)))
end

; ADAPTIVE JOB MARKET: Jobs adjust AI usage based on local skills
to adapt-ai-usage
  ask patches with [job?] [
    let available-skills 0
    if any? persons-here [
      set available-skills mean [education-level] of persons-here
    ]
    set job-ai-usage-level job-ai-usage-level +
      (ai-adjustment-speed * (1 - (available-skills / 3)))
    set job-ai-usage-level min list 1 job-ai-usage-level
  ]
end


; ================================
; POLICY INTERVENTIONS
; ================================

to implement-policy
  if ticks mod 365 = 0 [
    set tax-rate 0.1 + (0.4 * (count persons with [education-level = 1] / (count persons)))
    set ubi tax-rate * count persons / 1000
  ]
end

; ================================
; SPATIAL DYNAMICS
; ================================

to calculate-desirability
  ask patches [
    let avg-edu 0
    if any? persons-here [
      set avg-edu mean [education-level] of persons-here
    ]
    set desirability (0.3 * count persons-here with [has-job?]) +
                     (0.7 * avg-edu)
  ]
end


to migrate-persons
  ask persons [
    let best-patch max-one-of neighbors4 [desirability]
    if best-patch != patch-here [ move-to best-patch ]
  ]
end

; ================================
; TECHNOLOGY ADOPTION CURVE
; ================================

to update-ai-adoption
  let ai-users count patches with [job-ai-usage-level > 0.7]
  if ai-users > (count patches * 0.15) [
    ask patches with [job?] [
      set job-ai-usage-level min list 1 (job-ai-usage-level * 1.05)
    ]
  ]
end

; ================================
; COGNITIVE MODEL INTEGRATION
; ================================

to update-decisions
  ask persons [
    let ai 0
    if has-job? and assigned-job != nobody [
      set ai [job-ai-usage-level] of assigned-job
    ]
    set decision-making-level decision-making-level +
      (0.1 * (knowledge / 3) * (1 - privacy-level)) -
      (0.05 * ai)
    set decision-making-level min list 1 max list 0 decision-making-level
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
512
30
1099
618
-1
-1
17.55
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
118
38
182
73
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
228
37
290
73
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
13
251
178
311
Probability_education1
0.05
1
0
Number

INPUTBOX
228
250
396
310
Probability_education2
0.05
1
0
Number

INPUTBOX
226
341
298
401
Max_jobs
50.0
1
0
Number

INPUTBOX
102
342
175
402
Min_jobs
3.0
1
0
Number

PLOT
1206
31
1879
165
Society Privacy Level
NIL
NIL
0.0
100.0
0.0
1.0
true
true
"" ""
PENS
"mean value" 1.0 0 -6759204 true "" "plot mean [ privacy-level ] of persons"
"min value" 1.0 0 -7500403 true "" "plot min [ privacy-level ] of persons"
"max value" 1.0 0 -2674135 true "" "plot max [ privacy-level ] of persons"

PLOT
1207
183
1879
316
Society Decision Making Level
NIL
NIL
0.0
100.0
0.0
1.0
true
true
"" ""
PENS
"mean value" 1.0 0 -11221820 true "" "plot mean [decision-making-level] of persons"
"min value" 1.0 0 -7500403 true "" "plot min [decision-making-level] of persons"
"max value" 1.0 0 -2674135 true "" "plot max [decision-making-level] of persons"

PLOT
1207
484
1879
615
Society Knowledge
NIL
NIL
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"mean value" 1.0 0 -11221820 true "" "plot mean [knowledge] of persons"

PLOT
1207
332
1879
465
Society Education Distribution
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Up to Baccalaureate" 1.0 0 -16777216 true "" "plot count persons with [education-level = 1]"
"Up to Masters" 1.0 0 -14439633 true "" "plot count persons with [education-level = 2]"
"PhD or later on" 1.0 0 -2674135 true "" "plot count persons with [education-level = 3]"

SLIDER
13
174
184
207
Clearance_rate
Clearance_rate
0.0001
0.99
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
227
174
397
207
Laziness_factor
Laziness_factor
0.001
0.99
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
88
438
303
471
Skills_decay_threshold
Skills_decay_threshold
0.0001
0.9
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
58
586
334
619
Population_max_increase_per_tick
Population_max_increase_per_tick
0.0001
0.99
0.0551
0.005
1
NIL
HORIZONTAL

SLIDER
59
517
331
550
Population_max_death_per_tick
Population_max_death_per_tick
0.0001
0.99
0.01
0.005
1
NIL
HORIZONTAL

SLIDER
13
105
185
138
N_persons
N_persons
10
100
15.0
5
1
NIL
HORIZONTAL

SLIDER
225
104
397
137
Max_time
Max_time
100
1000
300.0
50
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model simulates the impact of AI usage on the knowledge, structure, and evolution of a society of workers. It explores how AI adoption, social networks, policies, spatial migration, and generational change interact to shape human knowledge, skills, and decision-making over time.



## HOW IT WORKS

The model represents a society of agents ("persons") with varying education, privacy, and decision-making abilities, embedded in a spatial world where jobs with different AI requirements appear and disappear. Social networks, skill transfer, adaptive jobs, policy interventions, migration, technology adoption, and generational turnover are all modeled.

### Initialization

**Agents** 
`N_persons` are created, each with:
  - Education level (`education-level`: 1, 2, or 3)
  - Decision-making (`decision-making-level`: ]0, 1[; 0 = fully AI, 1 = fully human)
  - Privacy (`privacy-level`: ]0, 1[; 0 = no privacy, 1 = high privacy)
  - Knowledge (initially set as `decision-making-level × education-level`)

**Social Network** 
Each person forms links with a few others, enabling knowledge and job information sharing.

**Jobs** 
A number of jobs (`Min_jobs` up to `Max_jobs`) are created on patches, each with:
  - Required education (`job-education-level`)
  - AI usage level (`job-ai-usage-level`)

### Tick Cycle

Each tick represents a time step in the society. The following processes occur:

**Job Market Refresh**  
   - Some jobs are deleted (`Clearance_rate`), and new jobs are created (`Min_jobs` to `Max_jobs`).
   - Jobs adapt their AI usage based on the skills of workers present.

**Job Assignment**  
   - Persons are matched to jobs if their education meets the job’s requirement.
   - On assignment, persons’ privacy erodes (`Laziness_factor × job-ai-usage-level`), and decision-making shifts toward AI.
   - Knowledge increases as a function of AI usage and education.

**Knowledge & Skill Dynamics**  
   - Over-reliance on AI can cause skill decay (education-level drops, knowledge drops 10%).
   - Persons share knowledge with their social network neighbors, simulating workplace learning.

**Population Change**  
   - A fraction of the population can reproduce (new persons inherit traits from parents).
   - Some persons may die, with lower-educated individuals protected by universal basic income (UBI) if policy is active.

**Policy Interventions**  
   - Tax rates and UBI are periodically recalculated based on the population’s education structure.

**Spatial Migration**  
   - Patches calculate a "desirability" score based on jobs and local education.
   - Persons may move to more desirable patches, simulating urban/rural migration.

**Technology Adoption**  
   - If enough jobs use high AI, AI adoption accelerates across the job market.

**Cognitive Model**  
   - Decision-making levels are updated based on knowledge, privacy, and AI exposure.



## HOW TO USE IT

### Population Settings

- `N_persons`: Initial population size
- `Probability_education1/2`: Education distribution probabilities
- `Population_max_increase_per_tick`: Maximum reproduction rate per tick
- `Population_max_death_per_tick`: Maximum death rate per tick

### Job Market

- `Min_jobs` / `Max_jobs`: Range of jobs created each tick
- `Clearance_rate`: Fraction of jobs deleted each tick

### AI & Knowledge

- `Laziness_factor`: Privacy erosion multiplier
- `Skills_decay_threshold`: Probability threshold for skill decay

### Policy

- `tax-rate` and `ubi` are managed automatically by the model

### Simulation

- `Max_time`: Total simulation duration (ticks)
- Use the `Setup` and `Go` buttons to run the simulation
- Be careful of the values chosen for `Max_time`, `Population_max_increase_per_tick` and `Population_max_death_per_tick` during your simulation.



## THINGS TO NOTICE

**AI Dependency Traps** : High AI usage could erode skills and privacy, especially for less-educated workers.

**Social Learning** : Knowledge can be preserved or spread through social networks, countering some negative AI effects.

**Migration & Segregation** : Agents may cluster in more desirable patches, leading to spatial inequality.

**Generational Turnover** : New generations may inherit lower education if skill decay is widespread.

**Policy Effects** : ubi could buffer low-education populations from excessive mortality.



## THINGS TO TRY

- Increase `Laziness_factor` to see how privacy and knowledge erode in high-AI societies.
- Experiment with job market sizes and spatial migration to see clustering effects.
- Observe how the social network structure affects knowledge retention.
- Lower `Skills_decay_threshold` to make skills more fragile.



## EXTENDING THE MODEL

- Add more nuanced policy interventions (e.g., AI regulation).
- Model different types of social networks (e.g., Small worlds).
- Implement more detailed migration rules.



## NETLOGO FEATURES

- Uses NetLogo’s `link` breed system for social networks.
- Implements adaptive patch variables and agent-based policy feedback.
- Demonstrates agent-based migration, dynamic job creation, and multi-generational reproduction.



## RELATED MODELS

- NetLogo "Wealth Distribution" and "Segregation" models for spatial/economic dynamics.



## CREDITS AND REFERENCES

- Perplexity AI, Inc.
- Data ScienceTech Institute Agent Base Modeling Course.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
