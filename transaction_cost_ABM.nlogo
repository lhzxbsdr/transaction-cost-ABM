 turtles-own [
  is-in-enterprise      ; is part of an enterprise
  enterprise-id         ; enterprise ID, -1 means no enterprise
  agent-type            ; agent type: raw1, raw2, raw3, inter1, inter2, final
  production            ; current production
  max-production        ; maximum production
  has-supply            ; has supply
  outgoing-links-count  ; outgoing links count
  current-tick-cost     ; Stores the total cost of incoming links for this tick
  missing-input-types   ; List of needed upstream agent types currently missing links
  joined-enterprise-this-tick? ; : Flag if agent joined/formed enterprise this tick
  created-link-this-tick? ;  Flag if agent created any link this tick
]

links-own [
  is-enterprise-link    ; is an enterprise link
  supply-amount         ; supply amount
]

globals [
  next-enterprise-id    ; next enterprise ID
  ; 移除锁定机制的全局变量
  ; locked-upstream-agents  ; locked upstream agents
  ; locked-downstream-agents ;   locked downstream agents for raw material allocation
  ; initial-production    ; REMOVED - Replaced by type-specific max-prod sliders
  total-enterprises      ; 总企业数量
  avg-enterprise-size    ; 平均企业规模
  total-transaction-cost ; 总交易成本
  avg-transaction-cost   ; 平均每个代理的交易成本
  cum-enterprises        ; 累计企业数量（用于图表）
  cum-transaction-cost   ; 累计交易成本（用于图表）
]

to setup
  clear-all

  set next-enterprise-id 0  ; 初始化企业ID为0
  ; 移除锁定机制的初始化
  ; set locked-upstream-agents []  ; 初始化上游锁定代理为空
  ; set locked-downstream-agents []  ; 初始化下游锁定代理为空
  ; 移除初始生产力的全局设置，使用类型特定滑块

  ; 初始化全局统计变量
  set total-enterprises 0
  set avg-enterprise-size 0
  set total-transaction-cost 0
  set avg-transaction-cost 0
  set cum-enterprises 0     ; 初始化累计企业数量
  set cum-transaction-cost 0 ; 初始化累计交易成本

  ; 设置背景为白色
  ask patches [ set pcolor white ]

  ; 创建原料代理
  create-turtles num-raw1 [
    set agent-type "raw1"
    set is-in-enterprise false
    set enterprise-id -1
    setxy random-xcor random-ycor
    set shape "circle"
    set color green
    set max-production max-prod-raw1
    set production max-production  ; 设置生产量
    set has-supply true  ; 设置拥有供应
    set outgoing-links-count 0
    ;set max-outgoing-links 3  ; 移除固定限制，由个体情况决定
    set label production  ; 设置标签
    set label-color black
    ; 初始化新属性
    set current-tick-cost 0
    set missing-input-types []
    set joined-enterprise-this-tick? false
    set created-link-this-tick? false
  ]
  create-turtles num-raw2 [
    set agent-type "raw2"
    set is-in-enterprise false
    set enterprise-id -1
    setxy random-xcor random-ycor
    set shape "circle"
    set color yellow
    set max-production max-prod-raw2 ; Use slider value
    set production max-production
    set has-supply true
    set outgoing-links-count 0
    set label production
    set label-color black
  ]
  create-turtles num-raw3 [
    set agent-type "raw3"
    set is-in-enterprise false
    set enterprise-id -1
    setxy random-xcor random-ycor
    set shape "circle"
    set color orange
    set max-production max-prod-raw3 ; Use slider value
    set production max-production
    set has-supply true
    set outgoing-links-count 0
    set label production
    set label-color black
  ]

  ; create turtles for intermediates
  create-turtles num-inter1 [
    set agent-type "inter1"
    set is-in-enterprise false
    set enterprise-id -1
    setxy random-xcor random-ycor
    set shape "square"
    set color cyan
    set production 0  ; Start with 0 production
    set max-production max-prod-inter1 ; Use slider value
    set has-supply false
    set outgoing-links-count 0
    set label production
    set label-color black
  ]
  create-turtles num-inter2 [
    set agent-type "inter2"
    set is-in-enterprise false
    set enterprise-id -1
    setxy random-xcor random-ycor
    set shape "square"
    set color magenta
    set production 0
    set max-production max-prod-inter2 ; Use slider value
    set has-supply false
    set outgoing-links-count 0
    set label production
    set label-color black
  ]

  ; create turtles for final products
  create-turtles num-final [
    set agent-type "final"
    set is-in-enterprise false
    set enterprise-id -1
    setxy random-xcor random-ycor
    set shape "triangle"
    set color gray
    set production 0
    set max-production max-prod-final ; Use slider value
    set has-supply false
    set outgoing-links-count 0
    set label production
    set label-color black
  ]

  ; move turtles to avoid crowding
  repeat 10 [
    ask turtles [
      let too-close other turtles in-radius 5
      if any? too-close [
        face min-one-of too-close [distance myself]
        fd -3
      ]
    ]
  ]

  reset-ticks
end

to go
  ; --- 0. Reset Tick-Specific Flags & Locks ---
  ask turtles [
    set joined-enterprise-this-tick? false
    set created-link-this-tick? false ; Reset the new flag for active decisions
  ]
  ; 移除锁定机制的重置
  ; set locked-upstream-agents [] ; Clear upstream locks
  ; set locked-downstream-agents [] ;   Clear downstream locks

  ; --- 1. Update Agent Status (Calculate Needs) ---
  ask turtles with [member? agent-type ["inter1" "inter2" "final"]] [
    update-agent-status
  ]

  ; --- 2. Upstream Optimization (Active Decision - Limited per agent) ---
  ask turtles with [member? agent-type ["inter1" "inter2" "final"]] [
    optimize-my-upstream-connections
  ]

  ; --- 3. Downstream Optimization (Raw materials) (Active Decision - Limited per agent) ---
  ask turtles with [member? agent-type ["raw1" "raw2" "raw3"]] [
      optimize-raw-agent-links
  ]

  ; --- 3.5 Downstream Optimization (Intermediates) (Active Decision - Limited per agent) ---
  ask turtles with [member? agent-type ["inter1" "inter2"]] [
      optimize-inter-agent-downstream-links
  ]

  ; --- 4. Update Supply and Production (MOVED UP) ---
  update-supply-and-production ; Calculate production based on links after optimization

  ; --- 5. Mandatory Cleanup & Cost Re-evaluation (Restored 1 & 3) ---
  check-and-break-invalid-links ; Break links if supplier production is insufficient
  ; check-and-remove-excess-links ; Remove excess links based on current production / max-production - STILL COMMENTED OUT
  reevaluate-link-types         ; Re-evaluate link type based on cost

  ; --- 6. Update Agent Costs and Display Labels ---
  update-agent-costs

  ; --- 7. 计算企业和成本数据 ---
  ; 先清理和重新标记企业ID
  cleanup-and-reassign-enterprise-ids

  ; --- 8. 仅更新链接标签，不改变颜色 ---
  ask links [
    set label supply-amount
    set label-color black
  ]

  ; --- 9. Layout Network ---
  layout-network

  ; --- 10. 计算企业和成本指标 ---
  let enterprise-ids []
  ask turtles with [enterprise-id != -1] [
    set enterprise-ids lput enterprise-id enterprise-ids
  ]
  let unique-ids remove-duplicates enterprise-ids

  ; 检查每个企业ID是否有至少两个代理通过企业链接连接
  let valid-enterprise-ids []
  foreach unique-ids [ eid ->
    let enterprise-members turtles with [enterprise-id = eid]
    if count enterprise-members >= 2 [
      ; 检查是否至少有一个企业链接连接这些成员
      let has-enterprise-links? any? links with [
        is-enterprise-link and
        [enterprise-id] of end1 = eid and
        [enterprise-id] of end2 = eid
      ]
      if has-enterprise-links? [
        set valid-enterprise-ids lput eid valid-enterprise-ids
      ]
    ]
  ]

  set total-enterprises length valid-enterprise-ids

  ; 累计企业数量
  set cum-enterprises cum-enterprises + total-enterprises

  ; 计算平均企业规模
  let enterprise-sizes []
  foreach valid-enterprise-ids [ eid ->
    ; 只计算直接通过企业链接连接的成员
    let connected-members find-connected-enterprise-members eid
    let enterprise-size count connected-members
    set enterprise-sizes lput enterprise-size enterprise-sizes
  ]

  ifelse not empty? enterprise-sizes [
    set avg-enterprise-size mean enterprise-sizes
  ][
    set avg-enterprise-size 0
  ]

  ; 计算交易成本 - 重新实现更准确的统计逻辑
  let current-total-cost 0
  let market-links-cost 0
  let enterprise-links-cost 0
  let market-links-count 0
  let enterprise-links-count 0

  ; 分别统计市场交易链接和企业内链接的成本和数量
  ask links [
    ifelse is-enterprise-link [
      ; 企业内链接 - 只计算单位成本
      let link-cost calculate-actual-link-cost self
      set enterprise-links-cost enterprise-links-cost + link-cost
      set enterprise-links-count enterprise-links-count + 1
    ] [
      ; 市场交易链接 - 只计算单位成本
      let link-cost calculate-actual-link-cost self
      set market-links-cost market-links-cost + link-cost
      set market-links-count market-links-count + 1
    ]
  ]

  ; 总交易成本是两种链接成本的总和
  set current-total-cost market-links-cost + enterprise-links-cost
  set total-transaction-cost current-total-cost

  ; 计算平均交易成本 - 基于链接类型的加权平均
  ifelse count links > 0 [
    ifelse market-links-count > 0 and enterprise-links-count > 0 [
      ; 如果两种链接都存在，计算总体平均
      set avg-transaction-cost total-transaction-cost / count links
    ] [
      ifelse market-links-count > 0 [
        ; 如果只有市场交易链接，平均成本应接近transaction-cost
        set avg-transaction-cost market-links-cost / market-links-count
      ] [
        ; 如果只有企业内链接
        set avg-transaction-cost enterprise-links-cost / enterprise-links-count
      ]
    ]
  ] [
    set avg-transaction-cost -1  ; 使用-1表示未定义，图表会忽略负值
  ]

  ; 更新累计交易成本
  set cum-transaction-cost cum-transaction-cost + total-transaction-cost

  ; --- 11. 先执行tick命令，再更新图表 ---
  tick

  ; --- 12. Update Plots ---
  update-plots

  ; 只在最后更新一次显示
  display
end

; update supply and production
to update-supply-and-production
  ; Reset production and supply status for non-raw agents first
  ask turtles with [not member? agent-type ["raw1" "raw2" "raw3"]] [
    set has-supply false
    set production 0
  ]

  ; Calculate production for non-raw agents based on inputs and recipe
  ask turtles with [not member? agent-type ["raw1" "raw2" "raw3"]] [
    let my-type agent-type
    let needed-upstream-types []
    let inputs-available [] ; List to store the amount received for each needed type
    let can-produce? true     ; Assume production is possible initially

    ; --- Determine Recipe ---
    if my-type = "final" [ set needed-upstream-types ["inter1" "inter2"] ]
    if my-type = "inter1" [ set needed-upstream-types ["raw1" "raw2"] ]
    if my-type = "inter2" [ set needed-upstream-types ["raw2" "raw3"] ]

    ; --- Check and Sum Inputs for Each Needed Type ---
    foreach needed-upstream-types [ upstream-type ->
      let links-of-this-type my-in-links with [ [agent-type] of end1 = upstream-type ]
      let total-supply-of-type sum [supply-amount] of links-of-this-type

      if total-supply-of-type <= 0 [
        set can-produce? false ; If any required input type has zero supply, cannot produce
      ]

      ; Store the available amount for this type
      set inputs-available lput total-supply-of-type inputs-available
    ]

    ; --- Set Production based on Recipe and Inputs ---
    if can-produce? [ ; Only proceed if all needed input types have > 0 supply
      set has-supply true

      ; Calculate recipe-limited production (assuming 1:1 inputs for now)
      ; Production is limited by the minimum available amount among all needed inputs.
      let recipe-limited-production min inputs-available

      ; Final production is the minimum of recipe-limited production and the agent's max capacity
      set production min list recipe-limited-production max-production
    ]
    ; If can-produce? is false, production remains 0 and has-supply remains false (set earlier)

    ; Update label (This is now redundant if update-agent-costs runs later, but keep for clarity here)
    ; set label production
    ; set label-color black
  ]

  ; update outgoing links count (for all turtles)
  ask turtles [
    set outgoing-links-count count my-out-links
  ]
end

; check and break invalid links
to check-and-break-invalid-links
  let any-action-taken? false ; Local flag

  ; Find all links whose supplier has no production
  let invalid-links links with [ [production] of end1 <= 0 ]

  if any? invalid-links [
    ; Only act if no action has been taken *within this function call* yet
    if not any-action-taken? [
      ; Choose one invalid link to break (e.g., the first one found or a random one)
      let link-to-break one-of invalid-links
      if link-to-break != nobody [ ; Ensure one was actually selected
        break-and-handle-enterprise link-to-break
        set any-action-taken? true ; Mark that an action was taken within this function
      ]
    ]
  ]
end

; optimize raw agent links
to optimize-raw-agent-links
  ; Called by raw material agents to optimize outgoing links.
  ; MODIFIED: Prioritize satisfying existing links, then create one new link if no existing link was optimized.

  if not member? agent-type ["raw1" "raw2" "raw3"] or production <= 0 [ stop ]

  let current-committed-supply sum [supply-amount] of my-out-links
  let remaining-production production - current-committed-supply ; Initial available surplus
  if remaining-production < 0 [ set remaining-production 0 ] ; Ensure non-negative starting point

  let action-taken? false ; Flag to ensure only one type of action

  ; --- Priority 1: Satisfy Existing Links ---
  if any? my-out-links and remaining-production > 0 [
    let sorted-links sort-by [[l1 l2] -> calculate-link-priority l1 > calculate-link-priority l2 ] my-out-links

    foreach sorted-links [ l ->
      ; Check action_taken? inside the loop to potentially stop optimizing after the first successful one if desired
      ; If we want to satisfy ALL possible existing links first, remove this 'if not action_taken?' check.
      ; Current logic: Try to satisfy all existing links before considering a new one.
      if remaining-production > 0 [ ; Still have production to allocate?
        let target [end2] of l
        ; Simplified target-needed calculation:
        ; *** Fix 2: Use parentheses to force evaluation order ***
        let links-from-same-type ( [my-in-links] of target ) with [[agent-type] of end1 = [agent-type] of myself]
        let target-current-supply sum [supply-amount] of links-from-same-type
        let target-needed max list 0 ([max-production] of target - target-current-supply) ; Needs for THIS type, ensure non-negative

        if target-needed > 0 [
          let extra-supply min list remaining-production target-needed ; How much we can give
          if extra-supply > 0 [
            ask l [
              set supply-amount supply-amount + extra-supply
              set label supply-amount
            ]
            set remaining-production remaining-production - extra-supply ; Reduce available surplus
            set action-taken? true ; Mark that we optimized an existing link
          ]
        ]
      ]
    ]
  ]

  ; --- Priority 2: Create ONE New Link (Only if NO existing link was optimized and capacity/slot available) ---
  if not action-taken? and remaining-production > 0 [
    ; No need to check created-link-this-tick? here, action_taken? handles the single-action rule.
    let potential-downstream find-potential-downstream
    if any? potential-downstream [
      ; 修改排序逻辑，为每个潜在目标计算实际成本
      let downstream-with-costs []

      ask potential-downstream [
        let target-cost calculate-potential-link-cost myself self
        set downstream-with-costs lput (list self target-cost) downstream-with-costs
      ]

      ; 按成本从低到高排序
      let sorted-downstream []
      if not empty? downstream-with-costs [
        let sorted-cost-pairs sort-by [ [p1 p2] -> item 1 p1 < item 1 p2 ] downstream-with-costs
        set sorted-downstream map [ p -> item 0 p ] sorted-cost-pairs
      ]

      let target nobody
      foreach sorted-downstream [ potential-target ->
        if target = nobody and
           not (out-link-neighbor? potential-target) and
           ([production] of potential-target < [max-production] of potential-target) [
             set target potential-target
        ]
      ]

      if target != nobody [
        ; Simplified max_needed calculation for the new link target
        ; *** Fix 2: Use parentheses to force evaluation order ***
        let links-from-same-type ( [my-in-links] of target ) with [[agent-type] of end1 = [agent-type] of myself]
        let target-current-supply sum [supply-amount] of links-from-same-type
        let max-needed max list 0 ([max-production] of target - target-current-supply)

        if max-needed > 0 [
           let initial-supply min list remaining-production max-needed
           if initial-supply > 0 [
             let success? try-establish-downstream-link-to target initial-supply
             if success? [
               set remaining-production remaining-production - initial-supply
               ; action_taken? remains true implicitly as this block only runs if it was false before
               ; created-link-this-tick? is set inside the helper
             ]
           ]
        ]
      ]
    ]
  ]

  set outgoing-links-count count my-out-links
end

; NEW HELPER for raw agent link priority calculation
to-report calculate-link-priority [ link-obj ]
  ; Higher number means higher priority (Enterprise > Transaction)
  let priority 0
  ifelse [is-enterprise-link] of link-obj [
     set priority 1000 ; High base priority for enterprise links
     ; 移除距离相关因素，优先级仅基于企业状态
  ] [
     set priority 500 ; 非企业连接的固定优先级
  ]
  report priority
end

; NEW HELPER for creating downstream link (to avoid code duplication)
to-report try-establish-downstream-link-to [ target initial-supply ]
  ; 计算潜在链接的成本
  let potential-cost calculate-potential-link-cost self target
  let should-be-enterprise? potential-cost < transaction-cost

  create-link-to target [
    set supply-amount initial-supply
    set label supply-amount
    set label-color black
    set is-enterprise-link should-be-enterprise?
    ifelse should-be-enterprise? [
      ; 不直接设置颜色，由handle-enterprise-formation函数设置
      handle-enterprise-formation end1 end2 ; Use the existing helper
    ] [
      set color gray - 2
    ]
  ]

  set created-link-this-tick? true ;   Flag that we created a link
  report true ; Link created successfully
end

; find potential downstream - 修改为不使用锁定机制
to-report find-potential-downstream
  let my-type agent-type
  let potential-downstream no-turtles

  ; check for intermediates
  if my-type = "raw1" [
    set potential-downstream turtles with [
      agent-type = "inter1" and
      production < max-production
      ; 完全删除链接数量限制
    ]
  ]

  if my-type = "raw2" [
    ; 对中间产品1的潜在下游
    let potential-inter1 turtles with [
      agent-type = "inter1" and
      production < max-production
      ; 完全删除链接数量限制
    ]

    ; 对中间产品2的潜在下游
    let potential-inter2 turtles with [
      agent-type = "inter2" and
      production < max-production
      ; 完全删除链接数量限制
    ]

    ; 合并两组潜在下游
    set potential-downstream (turtle-set potential-inter1 potential-inter2)
  ]

  if my-type = "raw3" [
    set potential-downstream turtles with [
      agent-type = "inter2" and
      production < max-production
      ; 完全删除链接数量限制
    ]
  ]

  ; 如果是中间代理，则使用中间代理查找下游的逻辑
  if member? my-type ["inter1" "inter2"] [
    ; 根据中间代理类型查找适合的下游
    if my-type = "inter1" [
      set potential-downstream turtles with [
        agent-type = "final" and
        production < max-production
        ; 完全删除链接数量限制
      ]
    ]

    if my-type = "inter2" [
      set potential-downstream turtles with [
        agent-type = "final" and
        production < max-production
        ; 完全删除链接数量限制
      ]
    ]
  ]

  report potential-downstream
end

; reevaluate link types
to reevaluate-link-types
  let any-action-taken? false ; Local flag for this function call

  ; Find links that should change from Enterprise to Transaction due to cost
  ; (respecting the skip flag for newly joined agents)
  let candidates links with [
    is-enterprise-link and
    (calculate-actual-link-cost self > transaction-cost) and
    (not ([joined-enterprise-this-tick?] of end1 or [joined-enterprise-this-tick?] of end2))
  ]

  if any? candidates [
     if not any-action-taken? [
      ; Choose one candidate to change (e.g., the first one found or random)
      let link-to-change one-of candidates
      if link-to-change != nobody [
        ask link-to-change [
          set is-enterprise-link false
          set color gray - 2
          let affected-end1 end1
          let affected-end2 end2

          ; 检查两个端点是否现在与企业断开
          ask affected-end1 [ check-enterprise-isolation ]
          ask affected-end2 [ check-enterprise-isolation ]

          ; 如果两个端点仍然在企业中但在不同的企业，则需要重新分配企业ID和颜色
          if [is-in-enterprise] of affected-end1 and [is-in-enterprise] of affected-end2 and
             [enterprise-id] of affected-end1 != [enterprise-id] of affected-end2 [
            ; 执行企业重新分配逻辑，通过cleanup-and-reassign-enterprise-ids完成
            ; 这个函数会重新设置所有企业链接的颜色，所以不需要在这里做
          ]
        ]
        set any-action-taken? true ; Mark that an action was taken within this function
      ]
    ]
  ]
end

; <<< ADD HELPER for can-join-or-create logic from original reevaluate procedure >>>
to-report check-can-join-or-create [ source-agent target-agent ]
  let source-type [agent-type] of source-agent
  let target-type [agent-type] of target-agent

  ; Rule 1: Prevent same type links within enterprise
  ; if source-type = target-type [ report false ] ; <<< COMMENTED OUT AS REQUESTED

  ; Rule 2 Check: Target joining source's enterprise
  ; *** 开始注释掉的部分 ***
  ; if [is-in-enterprise] of source-agent [
  ;   let enterprise-id-to-check [enterprise-id] of source-agent
  ;   ; Only perform the check if they are NOT already in the same enterprise
  ;   if not ([is-in-enterprise] of target-agent and [enterprise-id] of target-agent = enterprise-id-to-check) [
  ;     let same-type-downstream any? turtles with [
  ;       enterprise-id = enterprise-id-to-check and
  ;       agent-type = target-type and
  ;       who != [who] of target-agent
  ;     ]
  ;     if same-type-downstream [ report false ]
  ;   ]
  ; ]
  ; *** 结束注释掉的部分 ***

  ; Rule 2 Check: Source joining target's enterprise
  ; *** 开始注释掉的部分 ***
  ; if [is-in-enterprise] of target-agent [
  ;   let enterprise-id-to-check [enterprise-id] of target-agent
  ;   ; Only perform the check if they are NOT already in the same enterprise
  ;   if not ([is-in-enterprise] of source-agent and [enterprise-id] of source-agent = enterprise-id-to-check) [
  ;     let same-type-upstream any? turtles with [
  ;       enterprise-id = enterprise-id-to-check and
  ;       agent-type = source-type and
  ;       who != [who] of source-agent
  ;     ]
  ;     if same-type-upstream [ report false ]
  ;   ]
  ; ]
  ; *** 结束注释掉的部分 ***

  ; If all checks passed (or were commented out)
  report true
end

; layout network - Reverted to simpler layout-spring
to layout-network
  ; Use NetLogo's built-in spring layout algorithm
  ; repeat [number of iterations] [
  ;   layout-spring [agentset] [linkset] [spring-constant] [spring-length] [repulsion-constant]
  ; ]
  ; Parameters:
  ; - spring-constant: How stiff the springs are (0-1). Higher means stiffer.
  ; - spring-length: The ideal length of the springs (links).
  ; - repulsion-constant: How much nodes repel each other.

  ; --- MODIFIED: Increased spring-length and repeat count ---
  repeat 30 [
    layout-spring turtles links 0.2 8 3 ; Increased spring-length from 6 to 8
  ]

  ; Optional: Gently pull turtles towards the center to keep the layout compact
  ; ask turtles [
  ;   face patch 0 0
  ;   fd 0.05
  ; ]
end

; 新增：找出通过企业链接直接连接的企业成员
to-report find-connected-enterprise-members [eid]
  ; 选择一个种子节点
  let seed-agent one-of turtles with [enterprise-id = eid]
  if seed-agent = nobody [ report no-turtles ]

  ; 使用广度优先搜索找出所有通过企业链接连接的成员
  let queue (list seed-agent)
  let visited (turtle-set seed-agent)

  while [not empty? queue] [
    let current-agent first queue
    set queue but-first queue

    ; 找出所有通过企业链接连接的邻居
    let enterprise-neighbors turtle-set nobody
    ask current-agent [
      ; 检查入站链接
      ask my-in-links with [is-enterprise-link] [
        if [enterprise-id] of end1 = eid [
          set enterprise-neighbors (turtle-set enterprise-neighbors end1)
        ]
      ]
      ; 检查出站链接
      ask my-out-links with [is-enterprise-link] [
        if [enterprise-id] of end2 = eid [
          set enterprise-neighbors (turtle-set enterprise-neighbors end2)
        ]
      ]
    ]

    ; 添加未访问过的邻居到队列和已访问集合
    let new-neighbors enterprise-neighbors with [not member? self visited]
    set visited (turtle-set visited new-neighbors)
    set queue sentence queue [self] of new-neighbors
  ]

  report visited
end

; 新增：清理和重新标记企业ID
to cleanup-and-reassign-enterprise-ids
  ; 步骤1: 收集当前所有企业的链接颜色映射
  let enterprise-id-color-map []

  ask links with [is-enterprise-link] [
    let eid1 [enterprise-id] of end1
    let eid2 [enterprise-id] of end2

    ; 只处理相同企业ID的链接
    if eid1 = eid2 and eid1 != -1 [
      let idx position eid1 (map first enterprise-id-color-map)
      ifelse idx != false [
        ; 已有记录，确保保持同一个颜色
        let stored-color item 1 (item idx enterprise-id-color-map)
        if color != stored-color [
          set color stored-color
        ]
      ][
        ; 记录新的企业ID-颜色映射
        set enterprise-id-color-map lput (list eid1 color) enterprise-id-color-map
      ]
    ]
  ]

  ; 步骤2: 找出所有连通的企业组
  let connected-components []
  let unprocessed-agents turtles with [enterprise-id != -1]

  while [any? unprocessed-agents] [
    let start-agent one-of unprocessed-agents
    let current-eid [enterprise-id] of start-agent

    ; 找出与当前企业ID相同的所有代理
    let component turtles with [enterprise-id = current-eid]

    ; 添加到组件列表
    set connected-components lput component connected-components

    ; 从未处理代理中移除这些代理
    set unprocessed-agents unprocessed-agents with [not member? self component]
  ]

  ; 步骤3: 按规模从大到小排序企业组
  let sorted-components sort-by [[comp1 comp2] -> count comp1 > count comp2] connected-components

  ; 步骤4: 为每个企业组分配固定颜色 - 只使用彩色，排除灰色
  ; 定义鲜艳的彩色列表，不包含灰色和中性色
  let enterprise-colors [red orange yellow green lime turquoise cyan sky blue violet magenta pink]
  let next-id 0

  foreach sorted-components [ component ->
    ; 检查是否有企业链接连接这些代理
    let has-enterprise-links? false
    ask component [
      let my-enterprise-links my-links with [is-enterprise-link]
      if any? my-enterprise-links [
        let other-agents link-neighbors with [member? self component]
        if any? other-agents [
          set has-enterprise-links? true
        ]
      ]
    ]

    if has-enterprise-links? [
      ; 尝试保持现有企业ID
      let current-eid [enterprise-id] of one-of component
      let fixed-color nobody

      ; 查找现有ID的保存颜色
      let idx position current-eid (map first enterprise-id-color-map)
      if idx != false [
        set fixed-color item 1 (item idx enterprise-id-color-map)
        ; 检查是否为灰色 - 灰色的RGB值R=G=B
        if fixed-color = gray or fixed-color = white or fixed-color = black [
          ; 如果是灰色，重新分配一个彩色
          set fixed-color item (current-eid mod length enterprise-colors) enterprise-colors
        ]
      ]

      ; 如果没有保存颜色，分配新颜色
      if fixed-color = nobody [
        set fixed-color item (next-id mod length enterprise-colors) enterprise-colors
      ]

      ; 重新设置企业ID和链接颜色
      ask component [
        set enterprise-id current-eid
        set is-in-enterprise true

        ; 更新企业链接颜色为固定颜色
        ask my-links with [is-enterprise-link] [
          if member? end1 component and member? end2 component [
            set color fixed-color
          ]
        ]
      ]

      set next-id next-id + 1
    ]
  ]

  ; 更新next-enterprise-id全局变量
  set next-enterprise-id next-id
end

; do layout
to do-layout
  layout-network
end

; optimize final agent links - MODIFIED TO PRIORITIZE ONE ACTION (ESTABLISH > OPTIMIZE)
to optimize-final-agent-links
  ; stop if not final
  if agent-type != "final" [ stop ]

  ; Flag to track if an action was taken this tick
  let action-taken? false

  ; --- 1. Prioritize establishing new links ---
  ; Check if new upstream links are needed (production < max)
  if production < max-production [
    set action-taken? establish-final-new-links-once ; Try to establish ONE new link
  ]

  ; --- 2. If no new link established, optimize existing ---
  if not action-taken? [
    set action-taken? optimize-final-upstream-links-once ; Try to optimize ONE existing link
  ]
end

; optimize final upstream links - MODIFIED TO DO AT MOST ONE OPTIMIZATION
to-report optimize-final-upstream-links-once ;; Renamed and returns boolean
  let action-taken? false
  let needed-upstream-types ["inter1" "inter2"]

  ; evaluate needed upstream types
  foreach needed-upstream-types [ upstream-type ->
    ; *** CORRECTED: Check action_taken? before proceeding, NO STOP ***
    if not action-taken? [
      ; get current links, sort by enterprise status then distance
      let current-links sort-by [[l1 l2] ->
        ; 修改排序标准，仅考虑企业状态
        ([is-enterprise-link] of l1 and not [is-enterprise-link] of l2)
      ] my-in-links with [[agent-type] of end1 = upstream-type]

      ; foreach current link for this type
      foreach current-links [ link-obj ->
         ; *** CORRECTED: Check action_taken? before proceeding, NO STOP ***
        if not action-taken? [
          let source-agent [end1] of link-obj
          let source-available-production [production] of source-agent

          ; Decrease source available production by supply amount of its *other* outgoing links
          ask [my-out-links] of source-agent [
            if self != link-obj [ ; Don't subtract the commitment on the link we are evaluating
              set source-available-production source-available-production - supply-amount
            ]
          ]
          set source-available-production max list 0 source-available-production ; Ensure non-negative

          ; Calculate extra supply needed by self, respecting max-production
          let target_agent self
          let target_current_incoming sum [supply-amount] of my-in-links
          let target_remaining_capacity max list 0 (max-production - target_current_incoming)

          ; Calculate the actual extra supply that can be added
          let extra-supply min list source-available-production target_remaining_capacity

          if extra-supply > 0 [
            ; add extra supply to the link
            ask link-obj [
              set supply-amount supply-amount + extra-supply
              set label supply-amount
            ]
            ; *** ACTION TAKEN ***
            set action-taken? true
            ; *** REMOVED STOP ***
          ]
        ]
      ] ; End foreach current-links
    ]
  ] ; End foreach needed-upstream-types

  report action-taken?
end

; establish final new links - MODIFIED TO DO AT MOST ONE ESTABLISHMENT
to-report establish-final-new-links-once ;; Renamed and returns boolean
  let action-taken? false
  let needed-upstream-types ["inter1" "inter2"]
  let current-production-check production

  ; 如果已经在本tick中创建了链接，则停止
  if created-link-this-tick? [ report false ]

  ; stop if current production is greater than or equal to max production
  if current-production-check >= max-production [ report false ] ; No action needed

  ; evaluate needed upstream types
  foreach needed-upstream-types [ upstream-type ->
    ; *** CORRECTED: Check action_taken? before proceeding, NO STOP ***
    if not action-taken? [
      ; check if there are upstream partners of this type
      let has-upstream? any? in-link-neighbors with [agent-type = upstream-type]

      ; If no upstream link for this type exists and we still need production
      if not has-upstream? and current-production-check < max-production [
        let potential-partners turtles with [
          agent-type = upstream-type and
          production > 0 and
          not out-link-neighbor? myself and
          not in-link-neighbor? myself and
          ; 修复此处: 移除错误的方括号
          (production - sum [supply-amount] of my-out-links) > 0
        ]

        ; 为每个潜在合作伙伴计算成本
        let partners-with-costs []
        ask potential-partners [
          let cost calculate-potential-link-cost self myself
          set partners-with-costs lput (list self cost) partners-with-costs
        ]

        ; 按成本从低到高排序
        let sorted-partners []
        if not empty? partners-with-costs [
          let sorted-cost-pairs sort-by [ [p1 p2] -> item 1 p1 < item 1 p2 ] partners-with-costs
          set sorted-partners map [ p -> item 0 p ] sorted-cost-pairs
        ]

        ; check if any potential partners exist
        if not empty? sorted-partners [
          let target-partner first sorted-partners

          ; 计算该链接是否应该是企业链接
          let potential-cost calculate-potential-link-cost target-partner self
          let should-be-enterprise? potential-cost < transaction-cost

          ; Calculate the actual remaining production of the target partner
          let committed-supply sum [supply-amount] of [my-out-links] of target-partner
          let source-remaining-production ([production] of target-partner) - committed-supply

          ; calculate initial supply needed
          let my-needed max-production - current-production-check
          let initial-supply max list 0 (min list source-remaining-production my-needed) ; Ensure non-negative

          if initial-supply > 0 [
            ; create link
            ask target-partner [ ; Context: target-partner
              create-link-to myself [ ; Context: link
                set supply-amount initial-supply
                set label supply-amount
                set label-color black
                set is-enterprise-link should-be-enterprise?
                ifelse should-be-enterprise? [
                  set color blue
                  handle-enterprise-formation end1 end2
                ] [
                  set color gray - 2
                ]
              ] ; End create-link-to block (Context back to target-partner)
              set outgoing-links-count outgoing-links-count + 1
              set created-link-this-tick? true ; 源代理（创建链接的代理）设置标记
            ] ; End ask target-partner

            ; update current production check
            set current-production-check current-production-check + initial-supply
            ; *** ACTION TAKEN ***
            set action-taken? true
            ; *** REMOVED stop command ***
          ] ; End if initial-supply > 0
        ] ; End if not empty? sorted-partners
      ] ; End if not has-upstream?
    ]
  ] ; End foreach needed-upstream-types

  ; Update actual production if action was taken
  if action-taken? [
    set production current-production-check
    set label production
  ]
  report action-taken?
end

; check and remove excess links
to check-and-remove-excess-links
  let any-action-taken? false ; Local flag for this function call
  let best-candidate-link nobody
  let highest-removal-priority -1 ; Higher value means more likely to be removed

  ; --- Phase 1: Identify the single best candidate for removal across all agents/reasons ---

  ; Check Supplier Excess
  ask turtles with [outgoing-links-count > 0] [
    let total-supply-amount sum [supply-amount] of my-out-links
    if total-supply-amount > production [
      ; Find the link with the lowest 'keep' priority for this supplier
      let links-to-consider sort-by [[l1 l2] -> link-keep-priority l1 < link-keep-priority l2] my-out-links ; Lowest keep priority first
      if not empty? links-to-consider [ ; *** CORRECTED ***
        let candidate first links-to-consider
        ; Use inverse of keep priority as removal priority
        let removal-priority 1 / (link-keep-priority candidate + 0.001) ; Add epsilon to avoid division by zero
        if removal-priority > highest-removal-priority [
          set highest-removal-priority removal-priority
          set best-candidate-link candidate
        ]
      ]
    ]
  ]

  ; Check Receiver Excess (consider these candidates only if they have higher priority than supplier candidates)
  ask turtles with [not member? agent-type ["raw1" "raw2" "raw3"] and any? my-in-links] [
    let total-received-supply sum [supply-amount] of my-in-links
    if total-received-supply > max-production [
      ; Find the link with the highest cost for this receiver
      let links-to-consider sort-by [[l1 l2] -> calculate-actual-link-cost l1 > calculate-actual-link-cost l2] my-in-links ; Highest cost first
       if not empty? links-to-consider [ ; *** CORRECTED ***
        let candidate first links-to-consider
        ; Use cost as removal priority
        let removal-priority calculate-actual-link-cost candidate
         if removal-priority > highest-removal-priority [
          set highest-removal-priority removal-priority
          set best-candidate-link candidate
        ]
      ]
    ]
  ]

  ; --- Phase 2: Execute removal if a candidate was found and no action taken yet ---
  if best-candidate-link != nobody [
    if not any-action-taken? [
      break-and-handle-enterprise best-candidate-link
      set any-action-taken? true ; Mark that an action was taken within this function
    ]
  ]
end

; NEW HELPER REPORTER for sorting links based on removal priority
to-report link-keep-priority [ link-obj ]
  ; Calculates a score indicating how much a link should be kept.
  ; Higher score = higher priority to keep (lower priority to remove).
  let priority 0
  ifelse [is-enterprise-link] of link-obj [
    set priority 1000 ; High base priority for enterprise links
  ] [
    set priority 500  ; Lower base priority for transaction links
  ]
  ; Adjust priority based on cost: lower cost increases the priority to keep.
  ; We use (max_cost - actual_cost) for adjustment. Assume transaction-cost is a reasonable upper bound.
  ; Ensure the adjustment isn't negative if cost somehow exceeds transaction-cost.
  let cost-adjustment max list 0 (transaction-cost - (calculate-actual-link-cost link-obj))
  report priority + cost-adjustment
end

; <<< ADD NEW HELPER PROCEDURES >>>

; --- Cost Calculation Helpers ---

to-report calculate-actual-link-cost [ link-obj ]
  ; Reports the per-unit cost of an existing link
  let cost 0 ; Variable to hold the final cost

  ifelse [is-enterprise-link] of link-obj [
    ; --- Enterprise Link ---
    set cost transaction-cost ; Default to transaction cost, override if valid enterprise found
    let source-agent [end1] of link-obj
    let target-agent [end2] of link-obj
    let enterprise-id-to-use -1
    let enterprise-members no-turtles
    let enterprise-links-count 0
    let valid-enterprise? false

    ; Check if the link consistently belongs to a single enterprise
    if [enterprise-id] of source-agent = [enterprise-id] of target-agent and [enterprise-id] of source-agent != -1 [
      set enterprise-id-to-use [enterprise-id] of source-agent
      set enterprise-members turtles with [enterprise-id = enterprise-id-to-use]
      set enterprise-links-count count links with [ is-enterprise-link and member? end1 enterprise-members and member? end2 enterprise-members ]
      set valid-enterprise? true
    ]

    ; If a valid enterprise was found AND it has links, calculate the specific enterprise cost
    if valid-enterprise? and enterprise-links-count > 0 [
      let enterprise-size count enterprise-members
      ; 修改企业内链接的成本计算公式为 management-cost-rate * (节点数-1)^2 / link数
      set cost (management-cost-rate * ((enterprise-size - 1) ^ 2)) / enterprise-links-count
    ] ; If not valid or no links, cost remains the default (transaction-cost)

  ]
  [ ; --- Transaction Link (Else block for the main ifelse) ---
    set cost transaction-cost ; 移除距离因素
  ]

  report cost ; Single report statement at the end
end

to-report calculate-potential-link-cost [ potential-supplier target-agent ]
  ; Estimates the per-unit cost if target-agent connects to potential-supplier
  let cost 0 ; Variable to hold the final cost

  let should-be-enterprise? (management-cost-rate < transaction-cost)

  ifelse should-be-enterprise? [
    ; --- Estimate Enterprise Cost ---
    let estimated-size 0
    let existing-enterprise-id -1
    let potential_cost_calculated? false
    let enterprise1-id -1
    let enterprise2-id -1
    let enterprise1-members no-turtles
    let enterprise2-members no-turtles

    ; 确定预计的企业规模 - 考虑三种情况:
    ifelse [is-in-enterprise] of target-agent and [is-in-enterprise] of potential-supplier [
      ; 情况1: 两个代理都已在企业中
      ifelse [enterprise-id] of target-agent = [enterprise-id] of potential-supplier [
        ; 1.1: 已在同一企业 - 企业规模不变
        set existing-enterprise-id [enterprise-id] of target-agent
        set estimated-size count turtles with [enterprise-id = existing-enterprise-id]
      ][
        ; 1.2: 在不同企业 - 企业合并
        set enterprise1-id [enterprise-id] of target-agent
        set enterprise2-id [enterprise-id] of potential-supplier
        set enterprise1-members turtles with [enterprise-id = enterprise1-id]
        set enterprise2-members turtles with [enterprise-id = enterprise2-id]
        ; 合并后的总规模
        set estimated-size (count enterprise1-members) + (count enterprise2-members)
      ]
    ][
      ifelse [is-in-enterprise] of target-agent [
        ; 情况2: 目标代理在企业中，供应商不在
        set existing-enterprise-id [enterprise-id] of target-agent
        set estimated-size 1 + count turtles with [enterprise-id = existing-enterprise-id]
      ][
        ifelse [is-in-enterprise] of potential-supplier [
          ; 情况3: 供应商在企业中，目标代理不在
          set existing-enterprise-id [enterprise-id] of potential-supplier
          set estimated-size 1 + count turtles with [enterprise-id = existing-enterprise-id]
        ][
          ; 情况4: 两个代理都不在企业中 - 形成新企业
          set estimated-size 2
        ]
      ]
    ]

    ; 计算基于估计规模的成本
    if estimated-size > 0 [
      ; 直接获取相关企业的实际链接数量
      let estimated-links 0

      ; 根据不同情况计算估计的链接数量
      ifelse enterprise1-id != -1 and enterprise2-id != -1 [
        ; 合并企业情况 - 计算两个企业的链接总数
        let enterprise1-links count links with [
          is-enterprise-link and
          member? end1 enterprise1-members and
          member? end2 enterprise1-members
        ]
        
        let enterprise2-links count links with [
          is-enterprise-link and
          member? end1 enterprise2-members and
          member? end2 enterprise2-members
        ]
        
        ; 合并后的链接数(加1是新创建的链接)
        set estimated-links enterprise1-links + enterprise2-links + 1
        ; 确保至少为1，避免除以0
        set estimated-links max list 1 estimated-links
      ][
        ifelse existing-enterprise-id != -1 [
          ; 如果已经存在企业，获取该企业实际的链接数量
          let enterprise-members turtles with [enterprise-id = existing-enterprise-id]
          set estimated-links count links with [
            is-enterprise-link and
            member? end1 enterprise-members and
            member? end2 enterprise-members
          ]
          ; 确保至少为1，避免除以0
          set estimated-links max list 1 estimated-links
        ][
          ; 如果是新企业，则初始链接数为1（即将创建的这个链接）
          set estimated-links 1
        ]
      ]
      
      set cost (management-cost-rate * ((estimated-size - 1) ^ 2)) / estimated-links
      set potential_cost_calculated? true
    ]

    ; 如果成本计算失败，使用交易成本作为后备
    if not potential_cost_calculated? [
       set cost transaction-cost
    ]

  ] [
    ; --- 交易成本估计 ---
    set cost transaction-cost ; 移除距离因素
  ]

  report cost ; 返回最终成本
end

; --- List Helpers ---

to-report list-min-by-cost [ list-of-pairs ]
  ; Input: list of [item cost] pairs. Output: the pair with the minimum cost.
  if empty? list-of-pairs [ report nobody ]
  ; Replaced min-one-of with sort-by and first
  ; Corrected sort-by argument order: reporter block first, then list
  ; Use explicit [ [var1 var2] -> ...] syntax for comparison
  let sorted-pairs sort-by [ [pair1 pair2] -> item 1 pair1 < item 1 pair2 ] list-of-pairs
  report first sorted-pairs
end

to-report list-max-by-cost [ list-of-pairs ]
  ; Input: list of [item cost] pairs. Output: the pair with the maximum cost.
  if empty? list-of-pairs [ report nobody ]
  ; Replaced max-one-of with sort-by and first
  ; Corrected sort-by argument order: reporter block first, then list
  ; Use explicit [ [var1 var2] -> ...] syntax for comparison
  let sorted-pairs sort-by [ [pair1 pair2] -> item 1 pair1 > item 1 pair2 ] list-of-pairs
  report first sorted-pairs
end

; --- Link Management Helpers ---

; try-establish-upstream-link-to function - 修改为不使用锁定机制
to-report try-establish-upstream-link-to [ supplier recipient ]
  ; Attempts to create a link from supplier to recipient, returns true if successful
  ; Calculates initial supply and handles basic enterprise formation.

  ; Check if supplier can supply and recipient needs it
  let committed-supply sum [supply-amount] of [my-out-links] of supplier
  let source-available ([production] of supplier - committed-supply)
  let recipient-needed ([max-production] of recipient - [production] of recipient) ; Use current production

  if source-available <= 0 or recipient-needed <= 0 [ report false ] ; Cannot supply or doesn't need

  let initial-supply min list source-available recipient-needed ; Directly use the minimum
  if initial-supply <= 0 [ report false ] ; Check if the calculated minimum is zero or less

  ; Check if link already exists (should ideally be checked before calling, but double-check)
  if [out-link-neighbor? recipient] of supplier [ report false ]

  ; Check cost effectiveness (potential cost vs transaction cost)
  let potential-cost calculate-potential-link-cost supplier recipient
  let should-be-enterprise? (potential-cost < transaction-cost)

  ; Create the link
  ask supplier [
    create-link-to recipient [
      set supply-amount initial-supply
      set label supply-amount
      set label-color black
      set is-enterprise-link should-be-enterprise?
      ifelse should-be-enterprise? [
        ; 不直接设置颜色，由handle-enterprise-formation函数设置
        handle-enterprise-formation end1 end2 ; Let helper manage enterprise status
      ] [
        set color gray - 2
      ]
    ]
    set outgoing-links-count count my-out-links ; Update count
    set created-link-this-tick? true ; 标记创建链接的代理
  ]

  ; Move closer
  ask supplier [
    if distance recipient > 6 [
      face recipient
      fd distance recipient - 6
    ]
  ]

  report true ; Link created
end

to break-and-handle-enterprise [ link-obj ]
  ; Breaks a link and updates enterprise status if needed.
  if link-obj = nobody [ stop ]

  let was-enterprise false ; Initialize
  let end1-agent nobody
  let end2-agent nobody

  ; Get link properties in the context of link-obj and execute die
  ask link-obj [
    set was-enterprise is-enterprise-link ; Get within link context
    set end1-agent end1                 ; Get within link context
    set end2-agent end2                 ; Get within link context
    die                                 ; Destroy in link context
  ]

  ; Now end1-agent and end2-agent hold the correct turtle objects
  ; If it was an enterprise link, check if both ends need to leave the enterprise
  if was-enterprise [
    if end1-agent != nobody [ ask end1-agent [ check-enterprise-isolation ] ]
    if end2-agent != nobody [ ask end2-agent [ check-enterprise-isolation ] ]
  ]

  ; Update end1's outgoing links count (although it will be recalculated, keeping it updated is good practice)
  if end1-agent != nobody [ ask end1-agent [ set outgoing-links-count count my-out-links ] ]
end

; <<< 新增函数: 传播企业ID到所有连接的代理 >>>
to propagate-enterprise-id [agents-or-agent enterprise-id-to-propagate]
  ; 创建一个集合来跟踪初始代理
  let initial-agents nobody

  ; 判断输入是单个代理还是代理集合
  ifelse is-agent? agents-or-agent [
    ; 单个代理
    set initial-agents (turtle-set agents-or-agent)
  ][
    ; 代理集合
    set initial-agents agents-or-agent
  ]

  ; 创建一个队列用于广度优先搜索
  let queue []
  ; 将所有初始代理添加到队列
  ask initial-agents [
    set queue lput self queue
  ]

  ; 创建一个集合跟踪已访问的代理
  let visited initial-agents

  ; 当队列不为空时继续搜索
  while [not empty? queue] [
    ; 取出队列中的第一个代理
    let current-agent first queue
    set queue but-first queue

    ; 设置当前代理的企业ID
    ask current-agent [
      set is-in-enterprise true
      set enterprise-id enterprise-id-to-propagate
      set joined-enterprise-this-tick? true
    ]

    ; 查找所有通过企业链接连接的邻居
    let neighbors-to-visit no-turtles
    ask current-agent [
      let enterprise-neighbors turtle-set nobody
      ; 检查所有入站链接
      ask my-in-links with [is-enterprise-link] [
        set enterprise-neighbors (turtle-set enterprise-neighbors end1)
      ]
      ; 检查所有出站链接
      ask my-out-links with [is-enterprise-link] [
        set enterprise-neighbors (turtle-set enterprise-neighbors end2)
      ]

      ; 只添加未访问过的邻居到队列
      set neighbors-to-visit enterprise-neighbors with [not member? self visited]
    ]

    ; 将新邻居添加到已访问集合和队列
    set visited (turtle-set visited neighbors-to-visit)
    set queue sentence queue [self] of neighbors-to-visit
  ]

  display ; 更新显示
end

to handle-enterprise-formation [ agent1 agent2 ]
  ; Sets enterprise status when an enterprise link is formed or confirmed.
  ; Sets the joined-enterprise-this-tick? flag if status changes.

  ; 检查两个代理是否已在企业中
  ifelse [is-in-enterprise] of agent1 and [is-in-enterprise] of agent2 [
    ; 两个代理都在企业中
    ifelse [enterprise-id] of agent1 = [enterprise-id] of agent2 [
      ; 已在同一企业 - 无需操作
      ; 获取企业ID和颜色
      let current-enterprise-id [enterprise-id] of agent1
      let links-in-enterprise links with [
        is-enterprise-link and
        [enterprise-id] of end1 = current-enterprise-id and
        [enterprise-id] of end2 = current-enterprise-id
      ]
      ; 使用已存在链接的颜色
      if any? links-in-enterprise [
        let enterprise-color [color] of one-of links-in-enterprise
        ; 设置当前链接颜色
        if is-link? self [
          set color enterprise-color
        ]
      ]
    ][
      ; 在不同企业 - 需要合并
      let enterprise1-id [enterprise-id] of agent1
      let enterprise2-id [enterprise-id] of agent2

      ; 确定哪个企业更大（规模更大的企业吸收更小的）
      let enterprise1-members turtles with [enterprise-id = enterprise1-id]
      let enterprise2-members turtles with [enterprise-id = enterprise2-id]

      ; 获取和设置企业颜色
      let chosen-color red ; 默认颜色使用红色，避免灰色

      ; 获取企业1的颜色
      let links-in-enterprise1 links with [
        is-enterprise-link and
        [enterprise-id] of end1 = enterprise1-id and
        [enterprise-id] of end2 = enterprise1-id
      ]
      if any? links-in-enterprise1 [
        set chosen-color [color] of one-of links-in-enterprise1
        ; 检查是否为灰色，如果是则重新分配
        if chosen-color = gray or chosen-color = white or chosen-color = black [
          ; 定义鲜艳的彩色列表
          let enterprise-colors [red orange yellow green lime turquoise cyan sky blue violet magenta pink]
          set chosen-color item (enterprise1-id mod length enterprise-colors) enterprise-colors
        ]
      ]

      ; 如果企业2更大，获取企业2的颜色
      if count enterprise2-members > count enterprise1-members [
        let links-in-enterprise2 links with [
          is-enterprise-link and
          [enterprise-id] of end1 = enterprise2-id and
          [enterprise-id] of end2 = enterprise2-id
        ]
        if any? links-in-enterprise2 [
          set chosen-color [color] of one-of links-in-enterprise2
          ; 检查是否为灰色，如果是则重新分配
          if chosen-color = gray or chosen-color = white or chosen-color = black [
            ; 定义鲜艳的彩色列表
            let enterprise-colors [red orange yellow green lime turquoise cyan sky blue violet magenta pink]
            set chosen-color item (enterprise2-id mod length enterprise-colors) enterprise-colors
          ]
        ]
      ]

      ; 设置当前链接颜色
      if is-link? self [
        set color chosen-color
      ]

      ifelse count enterprise1-members >= count enterprise2-members [
        ; 企业1更大，将企业2并入企业1
        propagate-enterprise-id enterprise2-members enterprise1-id

        ; 设置所有企业链接的颜色为chosen-color
        ask links with [
          is-enterprise-link and
          ([enterprise-id] of end1 = enterprise1-id or [enterprise-id] of end2 = enterprise1-id)
        ] [
          set color chosen-color
        ]
      ][
        ; 企业2更大，将企业1并入企业2
        propagate-enterprise-id enterprise1-members enterprise2-id

        ; 设置所有企业链接的颜色为chosen-color
        ask links with [
          is-enterprise-link and
          ([enterprise-id] of end1 = enterprise2-id or [enterprise-id] of end2 = enterprise2-id)
        ] [
          set color chosen-color
        ]
      ]
    ]
  ][
    ifelse [is-in-enterprise] of agent1 [
      ; agent1在企业中，agent2不在
      let existing-id [enterprise-id] of agent1
      propagate-enterprise-id agent2 existing-id

      ; 获取企业的链接颜色
      let links-in-enterprise links with [
        is-enterprise-link and
        [enterprise-id] of end1 = existing-id and
        [enterprise-id] of end2 = existing-id
      ]
      if any? links-in-enterprise [
        let enterprise-color [color] of one-of links-in-enterprise
        ; 检查是否为灰色
        if enterprise-color = gray or enterprise-color = white or enterprise-color = black [
          ; 定义鲜艳的彩色列表
          let enterprise-colors [red orange yellow green lime turquoise cyan sky blue violet magenta pink]
          set enterprise-color item (existing-id mod length enterprise-colors) enterprise-colors
        ]
        ; 设置当前链接颜色
        if is-link? self [
          set color enterprise-color
        ]
      ]
    ][
      ifelse [is-in-enterprise] of agent2 [
        ; agent2在企业中，agent1不在
        let existing-id [enterprise-id] of agent2
        propagate-enterprise-id agent1 existing-id

        ; 获取企业的链接颜色
        let links-in-enterprise links with [
          is-enterprise-link and
          [enterprise-id] of end1 = existing-id and
          [enterprise-id] of end2 = existing-id
        ]
        if any? links-in-enterprise [
          let enterprise-color [color] of one-of links-in-enterprise
          ; 检查是否为灰色
          if enterprise-color = gray or enterprise-color = white or enterprise-color = black [
            ; 定义鲜艳的彩色列表
            let enterprise-colors [red orange yellow green lime turquoise cyan sky blue violet magenta pink]
            set enterprise-color item (existing-id mod length enterprise-colors) enterprise-colors
          ]
          ; 设置当前链接颜色
          if is-link? self [
            set color enterprise-color
          ]
        ]
      ][
        ; 两者都不在企业中，创建新企业
        let new-id next-enterprise-id
        set next-enterprise-id next-enterprise-id + 1

        propagate-enterprise-id agent1 new-id
        propagate-enterprise-id agent2 new-id

        ; 为新企业选择颜色（与cleanup-and-reassign-enterprise-ids中的逻辑保持一致）
        ; 定义鲜艳的彩色列表，不包含灰色和中性色
        let enterprise-colors [red orange yellow green lime turquoise cyan sky blue violet magenta pink]
        let enterprise-color item (new-id mod length enterprise-colors) enterprise-colors

        ; 设置当前链接颜色
        if is-link? self [
          set color enterprise-color
        ]
      ]
    ]
  ]

  display ; 更新显示
end

to check-enterprise-isolation
  ; 现在不仅检查直接连接，还递归检查通过企业链接的间接连接
  if not is-in-enterprise [ stop ] ; Already not in enterprise

  let my-current-id enterprise-id
  let my-direct-links my-links with [is-enterprise-link]

  ; 如果没有企业链接，直接离开企业
  if not any? my-direct-links [
    set is-in-enterprise false
    set enterprise-id -1
    display
    stop
  ]

  ; 检查是否还有同一企业的其他代理通过企业链接直接连接
  let still-directly-connected? any? my-direct-links with [[enterprise-id] of other-end = my-current-id]

  ; 如果直接连接的企业成员都不在了，需要重新传播并可能离开企业
  if not still-directly-connected? [
    ; 创建一个集合来跟踪当前代理可以到达的所有代理
    let reachable-agents turtle-set nobody

    ; 从每个直接连接的代理开始进行广度优先搜索
    foreach [self] of link-neighbors with [[is-enterprise-link] of link-with myself] [ neighbor ->
      ; 检查是否能通过企业链接从邻居到达同一企业的其他代理
      let queue (list neighbor)
      let visited (turtle-set neighbor)

      while [not empty? queue] [
        let current-agent first queue
        set queue but-first queue

        if [enterprise-id] of current-agent = my-current-id [
          set reachable-agents (turtle-set reachable-agents current-agent)
        ]

        let new-neighbors nobody
        ask current-agent [
          let enterprise-links my-links with [is-enterprise-link]
          ask enterprise-links [
            let next-agent other-end
            if not member? next-agent visited [
              set visited (turtle-set visited next-agent)
              set queue lput next-agent queue
            ]
          ]
        ]
      ]
    ]

    ; 如果没有可达的同一企业的其他代理，则离开企业
    if not any? reachable-agents [
      set is-in-enterprise false
      set enterprise-id -1
    ]

    ; 即使有可达的代理，也检查连通性以确保企业的完整性
    if any? reachable-agents [
      ; 检查该企业的所有代理是否都能互相连通
      let all-members turtles with [enterprise-id = my-current-id]
      let all-members-count count all-members

      ; 执行深度优先搜索来检查从当前代理出发能否到达所有企业成员
      let start-agent one-of reachable-agents
      if start-agent != nobody [
        let queue (list start-agent)
        let visited (turtle-set start-agent)

        while [not empty? queue] [
          let current-agent first queue
          set queue but-first queue

          ask current-agent [
            let enterprise-links my-links with [is-enterprise-link]
            ask enterprise-links [
              let next-agent other-end
              if [enterprise-id] of next-agent = my-current-id and not member? next-agent visited [
                set visited (turtle-set visited next-agent)
                set queue lput next-agent queue
              ]
            ]
          ]
        ]

        ; 如果访问的节点数小于企业的全部成员数，则说明企业不是完全连通的
        if count visited < all-members-count [
          ; 找出哪些节点没有被访问到，让它们离开企业
          ask all-members with [not member? self visited] [
            set is-in-enterprise false
            set enterprise-id -1
          ]
        ]
      ]
    ]
  ]

  display ; 添加显示更新
end

; <<< MODIFY CORE OPTIMIZATION PROCEDURE >>>

; optimize my upstream connections
to optimize-my-upstream-connections
  ; Called by inter and final agents to optimize incoming links based on cost.
  ; MODIFIED: Actions are limited based on whether a link was already created

  ;   If already created a link this tick, stop
  if created-link-this-tick? [ stop ]

  let my-type agent-type
  ; We still need needed-upstream-types for later checks (redundancy, replacement)
  let needed-upstream-types []
  if my-type = "final" [ set needed-upstream-types ["inter1" "inter2"] ]
  if my-type = "inter1" [ set needed-upstream-types ["raw1" "raw2"] ]
  if my-type = "inter2" [ set needed-upstream-types ["raw2" "raw3"] ]

  let cost-improvement-threshold 0.01
  let action-taken? false ; 标记是否已采取行动

  ; --- Priority 1: Create Missing Link (Only One Link per Tick) ---
  ; Use the status variable calculated by update-agent-status
  if not empty? missing-input-types and not action-taken? [
    let potential-new-suppliers-with-costs []
    ; Iterate through the *missing* types directly
    foreach missing-input-types [ missing-type ->
      let potential-partners turtles with [
         agent-type = missing-type and
         production > 0 and
         who != myself and
         ; 修复此处: 移除错误的方括号
         (production - sum [supply-amount] of my-out-links) > 0
         ; 删除重复的条件检查
         ; ([production] - sum [supply-amount] of my-out-links) > 0
      ]
      foreach (sort potential-partners) [ s ->
        let cost calculate-potential-link-cost s self
        if cost < 9999 [ ; Use a high number instead of transaction_cost to allow enterprise evaluation
          set potential-new-suppliers-with-costs lput (list s cost missing-type) potential-new-suppliers-with-costs
        ]
      ]
    ]

    ; Try to establish ONE link for missing types, starting with lowest potential cost
    if not empty? potential-new-suppliers-with-costs [
      let sorted-potential-actions sort-by [ [a1 a2] -> item 1 a1 < item 1 a2 ] potential-new-suppliers-with-costs
      let best-action first sorted-potential-actions
      let best-supplier item 0 best-action
      let missing-type-needed item 2 best-action

      ; 修复此处: 使用正确的语法
      if member? missing-type-needed missing-input-types and ([production] of best-supplier - sum [supply-amount] of [my-out-links] of best-supplier) > 0 [
        let success? try-establish-upstream-link-to best-supplier self
        if success? [
          ; Remove the successfully established type from the missing list for this tick
          set missing-input-types remove missing-type-needed missing-input-types
          ; We don't need to set created-link-this-tick? here as it's set in try-establish-upstream-link-to
          set action-taken? true ; 标记已采取行动，替换stop命令
        ]
      ]
    ]
  ]

  ; --- Priority 2: Remove ONE Invalid/Excess/Redundant Link (Limited to one action) ---
  ; (只有在未采取行动的情况下才会执行)
  if not action-taken? [
    ; ... 其他优化逻辑
  ]
end

; NEW HELPER for establishing upstream link
; 删除这里的整个try-establish-upstream-link-to函数，因为它是重复定义的

; NEW PROCEDURE: Update agent costs and labels
to update-agent-costs
  ask turtles with [not member? agent-type ["raw1" "raw2" "raw3"]] [
    let total-cost 0
    ask my-in-links [
      set total-cost total-cost + (calculate-actual-link-cost self * supply-amount) ; Cost per link * supply
    ]
    set current-tick-cost total-cost
    ; 只显示生产量，不再显示成本
    set label production
  ]
  ; 原材料代理只显示生产量
  ask turtles with [member? agent-type ["raw1" "raw2" "raw3"]] [
    set current-tick-cost 0 ; 原材料代理没有入站链接
    set label production
    set label-color black ; 原材料代理保持黑色标签
  ]
end

; <<< NEW PROCEDURE to Update Agent State Variables >>>
to update-agent-status
  ; Called by inter and final agents to determine their current input needs.

  ; Reset the list for this tick
  set missing-input-types []

  ; Determine required types based on self
  let needed-upstream-types []
  if agent-type = "final" [ set needed-upstream-types ["inter1" "inter2"] ]
  if agent-type = "inter1" [ set needed-upstream-types ["raw1" "raw2"] ]
  if agent-type = "inter2" [ set needed-upstream-types ["raw2" "raw3"] ]

  ; Check each needed type
  foreach needed-upstream-types [ required-type ->
    ; Check if there is at least one incoming link from a supplier of this type
    let has-link-for-type? any? my-in-links with [ [agent-type] of end1 = required-type ]
    if not has-link-for-type? [
      ; If no link exists for this required type, add it to the missing list
      set missing-input-types lput required-type missing-input-types
    ]
  ]

  ; Example of how other status variables could be set here:
  ; let current-supply sum [supply-amount] of my-in-links
  ; set has-sufficient-input (current-supply >= max-production)
  ; set has-excess-input (current-supply > max-production)
  ; ... etc ...
end

; 新增: 中间代理寻找下游链接的优化函数
to optimize-inter-agent-downstream-links
  ; Called by intermediate agents to optimize outgoing links.
  ; MODIFIED: Prioritize satisfying existing links, then create one new link if no existing link was optimized.

  if not member? agent-type ["inter1" "inter2"] or production <= 0 [ stop ]

  let current-committed-supply sum [supply-amount] of my-out-links
  let remaining-production production - current-committed-supply
  if remaining-production < 0 [ set remaining-production 0 ]

  let action-taken? false ; Flag to ensure only one type of action

  ; --- Priority 1: Satisfy Existing Links ---
  if any? my-out-links and remaining-production > 0 [
    let sorted-links sort-by [[l1 l2] -> calculate-link-priority l1 > calculate-link-priority l2 ] my-out-links

    foreach sorted-links [ l ->
       ; See comment in optimize-raw-agent-links about potentially checking action_taken? here.
       ; Current logic: Try to satisfy all existing links before considering a new one.
      if remaining-production > 0 [
        let target [end2] of l
        ; Simplified target-needed calculation:
        ; *** Fix 2: Use parentheses to force evaluation order ***
        let links-from-same-type ( [my-in-links] of target ) with [[agent-type] of end1 = [agent-type] of myself]
        let target-current-supply sum [supply-amount] of links-from-same-type
        let target-needed max list 0 ([max-production] of target - target-current-supply)

        if target-needed > 0 [
          let extra-supply min list remaining-production target-needed
          if extra-supply > 0 [
            ask l [
              set supply-amount supply-amount + extra-supply
              set label supply-amount
            ]
            set remaining-production remaining-production - extra-supply
            set action-taken? true ; Mark that we optimized an existing link
          ]
        ]
      ]
    ]
  ]

  ; --- Priority 2: Create ONE New Link (Only if NO existing link was optimized and capacity/slot available) ---
  if not action-taken? and remaining-production > 0 [
    ; 获取基本的潜在下游，但需要过滤出适合中间代理的
    let all-potential-downstream find-potential-inter-downstream
    ; 根据中间代理类型过滤潜在下游
    let potential-downstream no-turtles

    if agent-type = "inter1" [
      set potential-downstream all-potential-downstream with [agent-type = "final"]
    ]
    if agent-type = "inter2" [
      set potential-downstream all-potential-downstream with [agent-type = "final"]
    ]

    if any? potential-downstream [
      ; 修改排序逻辑，为每个潜在目标计算实际成本
      let downstream-with-costs []

      ask potential-downstream [
        let target-cost calculate-potential-link-cost myself self
        set downstream-with-costs lput (list self target-cost) downstream-with-costs
      ]

      ; 按成本从低到高排序
      let sorted-downstream []
      if not empty? downstream-with-costs [
        let sorted-cost-pairs sort-by [ [p1 p2] -> item 1 p1 < item 1 p2 ] downstream-with-costs
        set sorted-downstream map [ p -> item 0 p ] sorted-cost-pairs
      ]

      let target nobody
      foreach sorted-downstream [ potential-target ->
        if target = nobody and
           not (out-link-neighbor? potential-target) and
           ([production] of potential-target < [max-production] of potential-target) [
             set target potential-target
        ]
      ]

      if target != nobody [
        ; Simplified max_needed calculation for the new link target
        ; *** Fix 2: Use parentheses to force evaluation order ***
        let links-from-same-type ( [my-in-links] of target ) with [[agent-type] of end1 = [agent-type] of myself]
        let target-current-supply sum [supply-amount] of links-from-same-type
        let max-needed max list 0 ([max-production] of target - target-current-supply)

        if max-needed > 0 [
           let initial-supply min list remaining-production max-needed
           if initial-supply > 0 [
             let success? try-establish-downstream-link-to target initial-supply
             if success? [
               set remaining-production remaining-production - initial-supply
               ; action_taken? remains true implicitly as this block only runs if it was false before
               ; created-link-this-tick? is set inside the helper
             ]
           ]
        ]
      ]
    ]
  ]

  set outgoing-links-count count my-out-links
end

; 查找中间代理的潜在下游
to-report find-potential-inter-downstream
  let my-type agent-type
  let potential-downstream no-turtles

  ; check for intermediates
  if my-type = "raw1" [
    set potential-downstream turtles with [
      agent-type = "inter1" and
      production < max-production
      ; 完全删除链接数量限制
    ]
  ]

  if my-type = "raw2" [
    ; 对中间产品1的潜在下游
    let potential-inter1 turtles with [
      agent-type = "inter1" and
      production < max-production
      ; 完全删除链接数量限制
    ]

    ; 对中间产品2的潜在下游
    let potential-inter2 turtles with [
      agent-type = "inter2" and
      production < max-production
      ; 完全删除链接数量限制
    ]

    ; 合并两组潜在下游
    set potential-downstream (turtle-set potential-inter1 potential-inter2)
  ]

  if my-type = "raw3" [
    set potential-downstream turtles with [
      agent-type = "inter2" and
      production < max-production
      ; 完全删除链接数量限制
    ]
  ]

  ; 如果是中间代理，则使用中间代理查找下游的逻辑
  if member? my-type ["inter1" "inter2"] [
    ; 根据中间代理类型查找适合的下游
    if my-type = "inter1" [
      set potential-downstream turtles with [
        agent-type = "final" and
        production < max-production
        ; 完全删除链接数量限制
      ]
    ]

    if my-type = "inter2" [
      set potential-downstream turtles with [
        agent-type = "final" and
        production < max-production
        ; 完全删除链接数量限制
      ]
    ]
  ]

  report potential-downstream
end

; <<< END OF NEW/MODIFIED PROCEDURES >>>
@#$#@#$#@
GRAPHICS-WINDOW
726
14
1787
1076
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-40
40
-40
40
0
0
1
ticks
30.0

BUTTON
48
68
114
101
NIL
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
135
68
198
101
NIL
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

SLIDER
36
140
208
173
transaction-cost
transaction-cost
0
10
6.8
0.1
1
NIL
HORIZONTAL

SLIDER
219
140
407
173
management-cost-rate
management-cost-rate
0
1
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
37
221
209
254
num-raw1
num-raw1
0
100
24.0
1
1
NIL
HORIZONTAL

SLIDER
37
256
209
289
num-raw2
num-raw2
0
100
24.0
1
1
NIL
HORIZONTAL

SLIDER
37
291
209
324
num-raw3
num-raw3
0
100
24.0
1
1
NIL
HORIZONTAL

SLIDER
218
240
390
273
num-inter1
num-inter1
0
100
13.0
1
1
NIL
HORIZONTAL

SLIDER
218
279
390
312
num-inter2
num-inter2
0
100
8.0
1
1
NIL
HORIZONTAL

SLIDER
398
260
570
293
num-final
num-final
0
100
6.0
1
1
NIL
HORIZONTAL

BUTTON
217
69
297
102
goonce
go
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
323
69
419
102
do-layout
do-layout
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
34
365
206
398
max-prod-raw1
max-prod-raw1
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
34
400
206
433
max-prod-raw2
max-prod-raw2
0
200
20.0
1
1
NIL
HORIZONTAL

SLIDER
34
435
206
468
max-prod-raw3
max-prod-raw3
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
216
383
388
416
max-prod-inter1
max-prod-inter1
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
216
420
388
453
max-prod-inter2
max-prod-inter2
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
397
403
569
436
max-prod-final
max-prod-final
0
100
100.0
1
1
NIL
HORIZONTAL

PLOT
32
484
242
634
企业数量
时间步
数量
0.0
0.0
0.0
0.0
true
false
"" ""
PENS
"企业数量" 1.0 0 -2674135 true "" "plot total-enterprises"

PLOT
252
484
462
634
企业规模
时间步
规模
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"平均企业规模" 1.0 0 -13345367 true "" "plot avg-enterprise-size * 2"

PLOT
252
647
462
797
总交易成本
时间步
成本
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"总交易成本" 1.0 0 -2674135 true "" "plot total-transaction-cost"

PLOT
473
647
683
797
平均交易成本
时间步
成本/链接
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"平均交易成本" 1.0 0 -13345367 true "" "ifelse avg-transaction-cost >= 0 [plot avg-transaction-cost] [plotxy ticks -0.05]  ; 显示接近Y轴但明显区别于0的值表示N/A"

PLOT
31
647
241
797
链接
时间步
数量
0.0
10.0
0.0
25.0
true
false
"" ""
PENS
"总链接数" 1.0 0 -16777216 true "" "plot count links"
"企业链接数" 1.0 0 -13345367 true "" "plot count links with [is-enterprise-link]"
"普通链接数" 1.0 0 -7500403 true "" "plot count links with [not is-enterprise-link]"

PLOT
472
485
682
635
各类产品产量
时间步
产量
0.0
0.0
0.0
0.0
true
false
"" ""
PENS
"inter1" 1.0 0 -11221820 true "" "plot sum [production] of turtles with [agent-type = \"inter1\"]"
"inter2" 1.0 0 -5825686 true "" "plot sum [production] of turtles with [agent-type = \"inter2\"]"
"final" 1.0 0 -7500403 true "" "plot sum [production] of turtles with [agent-type = \"final\"]"

MONITOR
527
802
619
847
平均交易成本
avg-transaction-cost
3
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250 150 205 260 250

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
Polygon -7500403 true true 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -7500403 true true 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

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
