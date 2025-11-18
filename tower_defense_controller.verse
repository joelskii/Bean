using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Devices/CreativeAnimation }
using { /Fortnite.com/Devices/CreativeAnimation/InterpolationTypes }
using { /Verse.org/Assets}
using { /Verse.org/Colors}
using { SimulatorAssets }
using { /Fortnite.com/Characters}
using { /Fortnite.com/UI}
using { /UnrealEngine.com/Temporary/UI}
using { /Verse.org/Simulation/Tags }
using { /Verse.org/Random}
using { /Fortnite.com/AI}
using { /Fortnite.com/Animation/PlayAnimation}
using { /Fortnite.com/Game}
using { /Verse.org/Concurrency}


SimulatorAssets<public> := module:
    HealthBar<public> := module:

material_settings := struct:
    HealthBarMaterial : material
    MaterialIndex : int = 0
    BarColor : color = NamedColors.Red

Damagable_Damage_Number_VFX_Settings := class<concrete>():
    @editable
    VFXProp : creative_prop_asset = DefaultCreativePropAsset
    @editable
    Duration : float = 1.5
    @editable
    CameraOffset : float = -125.0
    @editable
    StartOffset : vector3 = vector3{Z:= 180.0}
    @editable
    FinalOffset : vector3 = vector3{Z:= 200.0}

round_config := class<concrete>:
    @editable
    RoundNumber : int = 1
    @editable
    EnemySpawnInterval : float = 5.0
    @editable
    EnemiesPerWave : int = 5
    @editable
    WaveCount : int = 3  # How many mini-waves in this round
    @editable
    AllowedRarities : []string = array{}
    @editable
    OnRoundCompleteDevice : trigger_device = trigger_device{}  # Fires when round won
    @editable
    OnRoundFailDevice : trigger_device = trigger_device{}  # Fires when king dies
    @editable
    IsLastRound : logic = false  # ✅ NEW - mark this as the final round
    @editable
    ContinueToInfiniteMode : logic = false  # ✅ NEW - if true, this round loops infinitely with increasing difficulty
    @editable
    InfiniteModeDifficultyMultiplier : float = 1.2  # ✅ NEW - how much harder each loop gets

king_death_config := class<concrete>:
    @editable
    DeathProp : creative_prop_asset = DefaultCreativePropAsset  # Skull/gravestone
    @editable
    DeathPropDuration : float = 5.0  # How long it shows
    @editable
    DeathAnimationProp : creative_prop_asset = DefaultCreativePropAsset  # ✅ SEPARATE PROP FOR ANIMATION
    @editable
    DeathAnimationDuration : float = 2.0  # ✅ How long animation shows
    @editable
    DeathAnimationOffset : vector3 = vector3{X := 0.0, Y := 0.0, Z := 100.0}  # ✅ Offset from king
    @editable
    DeathPropOffset : vector3 = vector3{X := 0.0, Y := 0.0, Z := 0.0}

    # King Route Selection UI Config
king_route_selection_ui_config := class<concrete>:
    @editable
    BackgroundTexture : texture = UIStuff.Random
    @editable
    BackgroundSize : vector2 = vector2{X := 600.0, Y := 400.0}
    @editable
    QuestionText : string = "Choose Your King Route"
    @editable
    ButtonTextSize : float = 24.0

# King Route - Contains independent progression for each route type
king_route := class<concrete>:
    @editable
    RouteName : string = "King"  # Display name (e.g., "King", "Queen", "Dragon")
    @editable
    RouteRebirths : []rebirth_config = array{}  # Independent rebirth progression for this route
    @editable
    InitialKing : king_character = king_character{}  # Starting king for this route

# Handler for route selection buttons
route_selection_button_handler := class:
    Controller : tower_defense_controller
    Agent : agent
    RouteIndex : int
    
    OnButtonClicked(Msg:widget_message) : void =
        if (Player := player[Msg.Player], Agent = agent[Player]):
            spawn{Controller.OnRouteSelected(Agent, RouteIndex)}

# Handler for route switch triggers
route_switch_trigger_handler := class:
    Controller : tower_defense_controller
    Agent : agent
    
    OnTriggered(MAgent : ?agent) : void =
        if (TriggeringAgent := MAgent?, TriggeringAgent = Agent):
            spawn{Controller.ShowRouteSelectionUI(Agent, true)}

CustomEvent := class<concrete>():
    var TDController : tower_defense_controller = tower_defense_controller{}
    @editable EventName : string = ""
    @editable StartEventTrigger : trigger_device = trigger_device{}
    @editable EventDurationTimer : timer_device = timer_device{}
    @editable BoostRarities : ?type{_X : float where _X >= 0.0, _X <= 1.0} = false
    @editable BoostVariants : ?type{_X : float where _X >= 0.0, _X <= 1.0} = false
    @editable OnlyAllowCertainRarities : ?[]string = false
    @editable OnlyAllowCertainDefenders : ?[]string = false
    @editable OnlyAllowCertainEnemies : ?[]string = false
    @editable OnlyAllowCertainVariants : ?[]string = false
    @editable PropsToHide : []creative_prop = array{}
    @editable PropsToShow : []creative_prop = array{}

    StartEvent(MAgent : ?agent) : void = spawn{HandleEvent()}
    HandleEvent()<suspends> : void =
        EventDurationTimer.Start()
        set TDController.CurrentEvent = option{Self}
        for(Prop : PropsToHide){Prop.Hide()}
        for(Prop : PropsToShow){Prop.Show()}
        EventDurationTimer.SuccessEvent.Await()
        set TDController.CurrentEvent = false
        for(Prop : PropsToHide){Prop.Show()}
        for(Prop : PropsToShow){Prop.Hide()}

CustomVariant := class<concrete>():
    @editable Name : string = ""
    @editable Chance : type{_X : float where _X >= 0.0, _X <= 1.0} = 0.0
    @editable DamageMultiplier : float = 1.0
    @editable HealthMultiplier : float = 1.0
    @editable IncomeMultiplier : float = 1.0
    @editable DisplayColor : color = color{}

CustomRarity := class<concrete><unique>():
    @editable Name : string = ""
    @editable Chance : type{_X : float where _X >= 0.0, _X <= 1.0} = 0.0
    @editable DisplayColor : color = color{}

# Add this class definition
HPDisplaySettings := class<concrete>:
    @editable
    HealthBarMaterialIndex : int = 0
    @editable
    Prop : creative_prop_asset = DefaultCreativePropAsset
    @editable
    ZOffset : int = 100
    @editable
    PropRotation : rotation = rotation{}
    @editable
    PropScale : vector3 = vector3{X:=1.0, Y:=1.0, Z:=1.0}
    MaterialIndex : int = 0
    BarColor : color = NamedColors.Red

king_character := class<concrete>:
    @editable
    PropAsset : creative_prop_asset = DefaultCreativePropAsset
    @editable
    Location : transform = transform{}
    @editable
    RotationOffset : float = 0.0 
    @editable
    MaxHealth : float = 500.0
    @editable
    CharacterName : string = "King"
    @editable
    AttackTransforms : []transform = array{} 
    @editable
    Variants : []king_variant = array{}  # ✅ ADD THIS LINE
    @editable
    EnableHealthBar : logic = true  # ✅ NEW: Enable HP bar above king
    @editable
    HealthBarSettings : HPDisplaySettings = HPDisplaySettings{}  # ✅ NEW

king_variant := class<concrete>:
    @editable
    VariantName : string = "King"
    @editable
    Level : int = 1
    @editable
    PropAsset : creative_prop_asset = DefaultCreativePropAsset
    @editable
    MaxHealthMultiplier : float = 1.0  # Multiply base king health
    @editable
    PropScale : vector3 = vector3{X:=1.0, Y:=1.0, Z:=1.0}

rebirth_config := class<concrete>:
    @editable
    RebirthLevel : int = 0  # 0 = starting level
    @editable
    RebirthName : string = "Rebirth 0"
    @editable
    DefenderPurchaseLimits : []int = array{}  # One limit per defender type (same order as Defenders array)
    @editable
    KingVariant : king_variant = king_variant{}
    @editable
    RebirthTrigger : trigger_device = trigger_device{}  # Trigger to activate this rebirth
    @editable
    RebirthCost : float = 0.0  # Optional: future currency cost
    @editable
    CannotRebirthDuringGameMessage : hud_message_device = hud_message_device{}
    @editable
    RebirthPropAssets : []creative_prop_asset = array{}  # ✅ CHANGED: Assets instead of props
    @editable
    RebirthPropTransforms : []transform = array{}  # ✅ NEW: One transform per asset
    


# Custom types for your props
defending_prop := class<concrete>:
    @editable
    PropAsset : creative_prop_asset = DefaultCreativePropAsset
    @editable
    InitialRotationOffset : float = 180.0
    @editable
    PurchaseTrigger : trigger_device = trigger_device{}
    @editable
    ProjectileAsset : creative_prop_asset = DefaultCreativePropAsset
    @editable
    Damage : float = 10.0
    @editable
    Range : float = 1000.0
    @editable
    FireRate : float = 1.0
    @editable
    MaxHealth : float = 100.0
    @editable
    ProjectileSpawnOffset : vector3 = vector3{X := 0.0, Y := 0.0, Z := 100.0}
    @editable
    ProjectileSpeed : float = 2000.0
    @editable
    ProjectileHitVFX : creative_prop_asset = DefaultCreativePropAsset
    @editable
    VFXDuration : float = 0.5  # How long VFX stays visible
    @editable
    ShootSound : audio_player_device = audio_player_device{}
    @editable
    HitSound : audio_player_device = audio_player_device{}
    @editable
    AttackAnimationProp : creative_prop_asset = DefaultCreativePropAsset  # ✅ PROP NOT DEVICE
    @editable
    AttackAnimationDuration : float = 0.5  # ✅ How long to show it
    @editable
    AttackAnimationOffset : vector3 = vector3{X := 0.0, Y := 0.0, Z := 0.0}  # ✅ Offset from defender
    @editable
    UpgradeVariants : []defender_variant = array{}  # Array of upgrade variants
    @editable
    UpgradeCost : float = 100.0  # Base cost to upgrade
    @editable
    UpgradeCostMultiplier : float = 1.5  # Cost multiplier per level
    @editable
    AttackType : attack_type = attack_type.NormalProjectile  # ✅ NEW
    @editable
    FreezeEffect : ?freeze_effect_config = false  # ✅ NEW - optional freeze
    @editable
    LightningConfig : ?lightning_config = false  # ✅ NEW - optional lightning settings
    @editable
    DamageNumberSettings : ?Damagable_Damage_Number_VFX_Settings = false
    @editable
    PurchaseCost : int = 100  # ✅ NEW - base cost in currency
    @editable
    CurrencyType : string = "Gold"  # ✅ NEW - which currency to use

    @editable
    HasSecondaryProp : logic = false  # ✅ Toggle for defenders that need extra props
    
    @editable
    SecondaryPropAsset : creative_prop_asset = DefaultCreativePropAsset  # ✅ The base/extra prop
    
    @editable
    SecondaryPropOffset : vector3 = vector3{X := 0.0, Y := 0.0, Z := -50.0}  # ✅ Offset from main prop (negative Z = below)
    
    @editable
    SecondaryPropRotationOffset : float = 0.0  # ✅ Optional rotation difference

    @editable
    MainPropPlacementOffset : vector3 = vector3{X := 0.0, Y := 0.0, Z := 0.0}

    # Attack type enum
attack_type := enum:
    NormalProjectile
    LightningStrike
    None

# Freeze effect config
freeze_effect_config := class<concrete>:
    @editable
    FreezeDuration : float = 2.0  # How long enemy is slowed
    @editable
    SpeedMultiplier : float = 0.3  # 0.3 = 30% speed (70% slow)
    @editable
    FreezeVFX : creative_prop_asset = DefaultCreativePropAsset  # Ice particles on enemy
    @editable
    VFXDuration : float = 2.0

# Lightning config
lightning_config := class<concrete>:
    @editable
    SpawnVFXAtDefender : creative_prop_asset = DefaultCreativePropAsset  # Flash at tower
    @editable
    VFXDuration : float = 0.3
    @editable
    SkyHeight : float = 2000.0  # How high above target lightning spawns
    @editable
    LightningSpeed : float = 5000.0  # Falls faster than normal projectile

defender_variant := class<concrete>:
    @editable
    VariantName : string = ""
    @editable
    Level : int = 1
    @editable
    DamageMultiplier : float = 1.0
    @editable
    RangeMultiplier : float = 1.0
    @editable
    FireRateMultiplier : float = 1.0  # Lower is faster
    @editable
    HealthMultiplier : float = 1.0
    @editable
    PropAsset : creative_prop_asset = DefaultCreativePropAsset  # Visual for this variant
    @editable
    AttackAnimationProp : creative_prop_asset = DefaultCreativePropAsset
    @editable

    @editable
    UseCustomMainPropOffset : logic = false  # If false, use base defender's offset
    
    @editable
    MainPropPlacementOffset : vector3 = vector3{X := 0.0, Y := 0.0, Z := 0.0}

    UseCustomSecondaryProp : logic = false  # If false, use base defender's secondary prop
    
    @editable
    SecondaryPropAsset : creative_prop_asset = DefaultCreativePropAsset
    
    @editable
    SecondaryPropOffset : vector3 = vector3{X := 0.0, Y := 0.0, Z := -50.0}
    
    @editable
    SecondaryPropRotationOffset : float = 0.0

VariantNPCSpawner := class<concrete>():
    @editable VariantName : string = ""
    @editable NPCSpawner : npc_spawner_device = npc_spawner_device{}
    @editable WalkAnimation : ?animation_sequence = false
    @editable AttackAnimation : ?animation_sequence = false

enemy_type := class<concrete>:
    @editable
    NPCDefinition : npc_spawner_device = npc_spawner_device{}
    @editable
    WalkAnimation : ?animation_sequence = false  # ADD: Optional walk anim
    @editable
    AttackAnimation : ?animation_sequence = false  # ADD: Optional attack anim
    @editable
    InitialRotationOffset : float = 180.0
    @editable
    Damage : float = 10.0
    @editable
    Range : float = 150.0
    @editable
    MaxHealth : float = 40.0
    @editable 
    AttackInterval : float = 1.0
    @editable
    MovementSpeed : float = 300.0
    @editable
    StopDistance : float = 100.0
    @editable
    EnableHealthBar : logic = false  # ADD THIS
    @editable
    HealthBarSettings : HPDisplaySettings = HPDisplaySettings{}
    @editable
    AttackSound : audio_player_device = audio_player_device{}
    @editable
    HitSound : audio_player_device = audio_player_device{}
    @editable
    DefeatedSound : audio_player_device = audio_player_device{}
    @editable Rarity : string = "Common"
    @editable RequireEvent : ?string = false
    @editable VariantNPCSpawners : []VariantNPCSpawner = array{}
    @editable
    DamageNumberSettings : ?Damagable_Damage_Number_VFX_Settings = false

class_selector_handler := class:
    Index : int
    Controller : tower_defense_controller
    
    HandleClassSwitched(Agent:agent):void =
        if (Cfg := Controller.PlayerConfigs[Index]):
            Controller.OnClassSwitch(Agent, Cfg, Index)  # ✅ Pass index

# Per-player configuration
player_config := class<concrete>:
    @editable
    Selector : class_and_team_selector_device = class_and_team_selector_device{}
    @editable
    StartWavesTrigger : trigger_device = trigger_device{} 
    @editable
    PauseButton : button_device = button_device{}
    @editable
    StopButton : button_device = button_device{}
    Mutator : mutator_zone_device = mutator_zone_device{}
    @editable
    Manipulator : prop_manipulator_device = prop_manipulator_device{}
    @editable
    DefensePlacementSpots : []defense_placement_spot = array{}
    @editable
    EnemySpawnTransforms : []transform = array{}
    @editable
    Defenders : []defending_prop = array{}
    @editable
    Attackers : []enemy_type = array{}
    @editable
    KingRoutes : []king_route = array{}  # ✅ NEW - Array of available routes
    @editable
    RouteSwitchTrigger : trigger_device = trigger_device{}  # ✅ NEW - Trigger to switch routes
    @editable
    RouteSelectionUIConfig : king_route_selection_ui_config = king_route_selection_ui_config{}  # ✅ NEW
    @editable
    CannotSwitchDuringGameMessage : hud_message_device = hud_message_device{}  # ✅ NEW
    @editable
    Rounds : []round_config = array{}
    @editable
    KingDeathConfig : king_death_config = king_death_config{}
    @editable
    WinTrigger : trigger_device = trigger_device{}  # ✅ Fires when player beats all rounds
    @editable
    ContinueUIConfig : continue_ui_config = continue_ui_config{}
    @editable AutoAssignClass : logic = true
    @editable KingBillboard : billboard_device = billboard_device{}
    @editable ConfigTeleporter : teleporter_device = teleporter_device{}
    @editable
    FarmManager : ?TD_Farm_Manager = false
    @editable
    JoinPlotPropAsset : creative_prop_asset = DefaultCreativePropAsset
    @editable
    JoinPlotPropTransform : transform = transform{}
    @editable
    CannotPlaceDuringRoundMessage : hud_message_device = hud_message_device{}  # ✅ NEW
    @editable
    CannotStartDuringRoundMessage : hud_message_device = hud_message_device{}  # ✅ NEW
    @editable
    CanOnlyPauseStopDuringRoundMessage : hud_message_device = hud_message_device{}  # ✅ NEW

    var CurrentRound : int = 0
    var RoundInProgress : logic = false
    var RoundUI : ?canvas = false  # Round display
    var RoundText : ?text_block = false
    var CurrentJoinPlotProp : ?creative_prop = false
    var IsOccupied : logic = false
    var OccupiedByAgent : ?agent = false

# Struct types for tracking props and their health
defense_unit := struct:
    Prop : creative_prop
    Health : float
    DefenderTypeIndex : int
    CurrentVariantLevel : int
    MaybeVariant : ?CustomVariant
    SecondaryProp : ?creative_prop

enemy_state := enum{ Walking, Attacking, Dead }
    
enemy_unit := struct:
    ID : int
    Agent : agent
    Health : float
    AttackerIndex : int
    IsAttacking : logic
    HealthBarProp : ?creative_prop
    IsDead : logic
    ScaledDamage : float
    MaybeVariant : ?CustomVariant
    FrozenUntil : float = 0.0  # ✅ NEW - tracks freeze time
    CurrentSpeedMultiplier : float = 1.0  # ✅ NEW - tracks speed reduction

    
    
player_state := class<concrete>:
    Config : player_config = player_config{}
    var Defenses : []defense_unit = array{}
    var Enemies : []enemy_unit = array{}
    var HPTrackerRunning : [int]logic = map{}
    var KingHealth : float = 500.0
    var KingHealthBar : ?color_block = false
    var KingHealthText : ?text_block = false
    var KingUIContainer : ?widget = false
    var CurrentRound : int = 0  
    var RoundInProgress : logic = false  
    var RoundUI : ?canvas = false  
    var RoundText : ?text_block = false  
    var SavedDefenderPlacements : [int]tuple(int, int) = map{}
    var DefenderLastFireTime : [int]float = map{}
    var EnemyRemovalLock : logic = false
    var DefenderRemovalLock : logic = false
    var GameRunning : logic = false 
    var GamePaused : logic = false
    var PausedAtRound : int = 0
    var PausedAtWave : int = 0
    var RoundLoopCount : int = 0
    var CurrentRebirthLevel : int = 0
    var DefenderPurchaseCounts : [int]int = map{}
    var CurrentKingProp : ?creative_prop = false
    var CurrentKingMaxHealth : float = 500.0
    var ContinueUICanvas : ?canvas = false
    var WaitingForContinueChoice : logic = false
    var SelectedKingRoute : int = -1
    var KingRouteProgress : [int]int = map{}
    var RouteSelectionUICanvas : ?canvas = false
    var WaitingForRouteSelection : logic = false
    var CurrentRebirthProps : []creative_prop = array{}
    var KingHealthBarProp : ?creative_prop = false  # ✅ NEW: HP bar above king



defense_placement_spot := class<concrete>:
    @editable
    PlacementButton : button_device = button_device{}  # Button to place defender here
    @editable
    UpgradeButton : button_device = button_device{}    # Button to upgrade (shows after placement)
    @editable
    Location : transform = transform{}  # Where the defender goes
    @editable
    RotationOffset : float = 0.0  # CHANGED
    var IsOccupied : logic = false
    var PlacedDefender : ?defense_unit = false
    var PlacedDefenderArrayIndex : int = -1  # ADD THIS - track actual index in State.Defenses

    var CurrentUpgradeCost : float = 0.0

    # NEW: Attack positions for this defender
    @editable
    AttackTransforms : []transform = array{}

continue_ui_config := class<concrete>:
    @editable
    BackgroundTexture : texture = UIStuff.Random
    @editable
    BackgroundSize : vector2 = vector2{X := 600.0, Y := 300.0}
    @editable
    QuestionText : string = "Do you want to continue?"
    @editable
    ContinueButtonText : string = "Continue"
    @editable
    StopButtonText : string = "Stop"

carried_defender := struct:
    Prop : creative_prop
    DefenderIndex : int  # Which defender type this is
    CarryingAgent : agent

upgrade_defender_handler := class:
    Controller : tower_defense_controller
    Agent : agent
    SpotIndex : int
    
    OnInteracted(InteractingAgent : agent) : void =
        if (InteractingAgent = Agent):
            spawn{Controller.UpgradeDefender(Agent, SpotIndex)}

purchase_defender_handler := class:
    Controller : tower_defense_controller
    Agent : agent
    DefenderIndex : int
    Config : player_config
    
    OnTriggered(MAgent : ?agent) : void =
        if (TriggeringAgent := MAgent?, TriggeringAgent = Agent):
            if (State := Controller.States[Agent]):
                # ✅ BLOCK IF GAME IS RUNNING
                if (State.GameRunning = true):
                    Config.CannotPlaceDuringRoundMessage.Show(Agent)
                    return
                
                if (DefenderIndex >= 0, DefenderIndex < Config.Defenders.Length):
                    if (Def := Config.Defenders[DefenderIndex]):
                        if (Character := TriggeringAgent.GetFortCharacter[]):
                            SpawnPos := Character.GetTransform().Translation
                            FixedTransform := Controller.FixTransform(transform{Translation := SpawnPos, Rotation := rotation{}, Scale := vector3{X:=1.0, Y:=1.0, Z:=1.0}})
                            DefRot := MakeRotation(Axis := vector3{X := 0.0, Y := 0.0, Z := 1.0}, AngleRadians := DegreesToRadians(Def.InitialRotationOffset))
                            Result := SpawnProp(Def.PropAsset, FixedTransform.Translation, DefRot)
                            if (SpawnedProp := Result(0)?):
                                NewCarried := carried_defender{Prop := SpawnedProp, DefenderIndex := DefenderIndex, CarryingAgent := TriggeringAgent}
                                set Controller.CarriedDefenders += array{NewCarried}
                                spawn{Controller.FollowPlayerWithDefender(SpawnedProp, TriggeringAgent)}

placement_button_handler := class:
    Controller : tower_defense_controller
    Agent : agent
    SpotIndex : int
    Config : player_config
    
    OnInteracted(InteractingAgent : agent) : void =
        if (InteractingAgent = Agent):
            # ✅ BLOCK IF GAME IS RUNNING
            if (State := Controller.States[Agent]):
                if (State.GameRunning = true):
                    Config.CannotPlaceDuringRoundMessage.Show(Agent)
                    return
            
            if (Spot := Config.DefensePlacementSpots[SpotIndex]):
                var CarriedDefender : ?carried_defender = false
                for (Carried : Controller.CarriedDefenders):
                    if (Carried.CarryingAgent = Agent):
                        set CarriedDefender = option{Carried}
                
                if (CD := CarriedDefender?):
                    spawn{Controller.PlaceDefenderAtSpot(Agent, CD, Spot, SpotIndex)}

rebirth_trigger_handler := class:
    Controller : tower_defense_controller
    Agent : agent
    RebirthIndex : int
    
    OnTriggered(MAgent : ?agent) : void =
        if (TriggeringAgent := MAgent?, TriggeringAgent = Agent):
            spawn{Controller.HandleRebirth(Agent, RebirthIndex)}

pause_button_handler := class:
    Controller : tower_defense_controller
    Agent : agent
    
    OnInteracted(InteractingAgent : agent) : void =
        if (InteractingAgent = Agent):
            Controller.HandlePauseToggle(Agent)

stop_button_handler := class:
    Controller : tower_defense_controller
    Agent : agent
    
    OnInteracted(InteractingAgent : agent) : void =
        if (InteractingAgent = Agent):
            Controller.HandleStopGame(Agent)

tower_defense_enemy_behavior := class(npc_behavior):
    var Controller : tower_defense_controller = tower_defense_controller{}
    var EnemyID : int = 0
    var OwnerAgent : ?agent = false
    ReadyEvent : event() = event(){}

    OnBegin<override>()<suspends>:void =
        ReadyEvent.Await() 
        spawn. MainLoop()
    
    MainLoop()<suspends>:void =
        if:
            NAgent := GetAgent[]
            Owner := OwnerAgent?
        then:
            Controller.MoveEnemyNPC(Owner, NAgent, EnemyID)

# Routine class to handle animation playback
animation_routine := class:
    var IsCancelled : logic = false
    
    Cancel():void =
        set IsCancelled = true
    
    PlayAnimation(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float)<suspends>:void =
        race:
            block:
                Anim.PlayAndAwait(Seq)
            block:
                Sleep(AttackInterval)
            block:
                loop:
                    if (IsCancelled = true):
                        break
                    Sleep(0.1)

# ✅ FIXED: Properly capture cancelable to prevent animation stacking
animation_manager := class:
    var CurrentDefenderIndex : int = -1
    var CurrentRoutine : ?cancelable = false
    
    StartAnimation(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float, DefenderIndex:int):void =
        # ✅ ALWAYS cancel previous animation first
        CancelAllAnimations()
        
        # ✅ UPDATE defender index
        set CurrentDefenderIndex = DefenderIndex
        
        # ✅ CAPTURE the cancelable from spawn
        NewRoutine := spawn{PlayAnimationAsync(Anim, Seq, AttackInterval)}
        set CurrentRoutine = option{NewRoutine}
    
    CancelAllAnimations():void =
        if (Routine := CurrentRoutine?):
            Routine.Cancel()
            set CurrentRoutine = false
        set CurrentDefenderIndex = -1
    
    PlayAnimationAsync(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float)<suspends>:void =
        Anim.PlayAndAwait(Seq)
        Sleep(AttackInterval)


# Main device
tower_defense_controller := class(creative_device):
    @editable
    PlayerConfigs : []player_config = array{}
    @editable
    CarryOffset : vector3 = vector3{X := 100.0, Y := 0.0, Z := 50.0}  # NEW: for carrying
    @editable Rarities : []CustomRarity = array{}
    @editable Variants : []CustomVariant = array{CustomVariant{Name := "None"}}
    @editable AllEvents : []CustomEvent = array{}
    @editable
    EconomyManager : economy_manager = economy_manager{}
    @editable
    TDPersistenceManager : Base_TD_Persistence_Manager = Base_TD_Persistence_Manager{}
    @editable AutoAssignPlot : logic = false

    var CurrentEvent : ?CustomEvent = false

    var States : [agent]player_state = map{}
    var PlayerToAgent : [player]agent = map{}
    var CarriedDefenders : []carried_defender = array{}  # NEW: track carried props
    var AnimationManagers : [agent]animation_manager = map{}

    

         
    OnBegin<override>()<suspends>:void =
        GetSimulationElapsedTime()
        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerJoined)
        GetPlayspace().PlayerRemovedEvent().Subscribe(OnPlayerLeft)
        InitializeEvents()
    
        # ✅ SPAWN JOIN PLOT PROPS FOR ALL CONFIGS AT START
        for(Idx := 0..Self.PlayerConfigs.Length-1):
            if (Cfg := Self.PlayerConfigs[Idx]):
                SpawnJoinPlotProp(Cfg)
        
        Players := GetPlayspace().GetPlayers()
        for (Idx := 0..Self.PlayerConfigs.Length-1):
            if (Cfg := Self.PlayerConfigs[Idx]):
                Handler := class_selector_handler{Index := Idx, Controller := Self}
                Cfg.Selector.ClassSwitchedEvent.Subscribe(Handler.HandleClassSwitched)
                Cfg.StartWavesTrigger.TriggeredEvent.Subscribe(Self.HandleStartWaves)


                # ✅ PLAYER JOINED EVENT

            # ✅ PLAYER JOINED - Immediately call init + assign
    var InitializedPlayers : []player = array{}
    OnPlayerJoined(Player : player) : void =
        Print("PLAYER JOINED")
        # ✅ SKIP IF ALREADY INITIALIZED
        if (InitializedPlayers.Find[Player]):
            Print("Player already initialized, skipping")
            return
        
        set InitializedPlayers += array{Player}
        # ✅ REMOVED AUTO-ASSIGNMENT - Players must click Join Plot prop
        Print("Player joined but not auto-assigned (waiting for Join Plot interaction)")

    SpawnJoinPlotProp(Cfg:player_config):void =
        # Dispose old prop if it exists
        if (OldProp := Cfg.CurrentJoinPlotProp?):
            if (OldProp.IsValid[]):
                OldProp.Dispose()
        
        # Spawn new prop
        FixedTransform := FixTransform(Cfg.JoinPlotPropTransform)
        
        Result := SpawnProp(Cfg.JoinPlotPropAsset, FixedTransform.Translation, FixedTransform.Rotation)
        if (NewProp := Result(0)?):
            NewProp.Show()
            set Cfg.CurrentJoinPlotProp = option{NewProp}
            Print("🔥 SPAWNED JOIN PLOT PROP - STORED")
        else:
            Print("🔥 FAILED TO SPAWN JOIN PLOT PROP!")

    InitializeAndAssignPlayer(InAgent : agent)<suspends> : void=
        Sleep(0.1)
        if (P := player[InAgent], not P.IsActive[]): 
            return
        
        var FoundConfig : ?player_config = false
        var FoundIndex : int = -1
        
        # If global AutoAssignPlot is enabled, pick first available config
        if (AutoAssignPlot?):
            for(idx := 0..PlayerConfigs.Length-1):
                if (PCfg := PlayerConfigs[idx], not FoundConfig?):
                    set FoundConfig = option{PCfg}
                    set FoundIndex = idx  # ✅ Track index here
        else:
            # Otherwise check for configs with AutoAssignClass enabled
            for(idx := 0..PlayerConfigs.Length-1):
                if (PCfg := PlayerConfigs[idx], not FoundConfig?):
                    if(PCfg.AutoAssignClass?):
                        set FoundConfig = option{PCfg}
                        set FoundIndex = idx  # ✅ Track index here
        
        # Assign to config if found
        if (SelectedConfig := FoundConfig?):
            OnClassSwitch(InAgent, SelectedConfig, FoundIndex)  # ✅ Pass index
        else:
            Print("⚠️ NO CONFIG AVAILABLE FOR AUTO-ASSIGN")

    OnPlayerLeft(Player:player):void =
        if (not Player.IsActive[]): 
            return
        Print("PLAYER LEFT: CLEANING UP")
        if (Agent := PlayerToAgent[Player]):
            Print("FOUND AGENT FOR LEAVING PLAYER")
            if (State := States[Agent]):
                # Dispose all defender props
                for (Def : State.Defenses):
                    if (Def.Prop.IsValid[]):
                        Def.Prop.Dispose()
                    # ✅ ADD THIS
                    if (SecondaryProp := Def.SecondaryProp?):
                        if (SecondaryProp.IsValid[]):
                            SecondaryProp.Dispose()
    
                # Kill all enemy NPCs  
                for (Enemy : State.Enemies):
                    if (EnemyChar := Enemy.Agent.GetFortCharacter[]):
                        if (Dmg := damageable[EnemyChar]):
                            Dmg.Damage(99999.0)
                    if (HPBar := Enemy.HealthBarProp?):
                        HPBar.Dispose()
                
                # ✅ CLEANUP PLACEMENT SPOTS
                for (Spot : State.Config.DefensePlacementSpots):
                    CleanupPlacementSpot(Spot)
                
                # ✅ CLEANUP REBIRTH PROPS
                for (Prop : State.CurrentRebirthProps):
                    if (Prop.IsValid[]):
                        Prop.Dispose()
                
                # ✅ CLEANUP KING HP BAR
                if (KingHPBar := State.KingHealthBarProp?):
                    if (KingHPBar.IsValid[]):
                        KingHPBar.Dispose()
                
                # Clean up carried defenders for this player
                var NewCarriedList : []carried_defender = array{}
                for (Carried : CarriedDefenders):
                    if (Carried.CarryingAgent <> Agent):
                        set NewCarriedList += array{Carried}
                    else:
                        if (Carried.Prop.IsValid[]):
                            Carried.Prop.Dispose()
                set CarriedDefenders = NewCarriedList

                # ✅ FIX: CLEANUP ANIMATION MANAGERS FOR THIS PLAYER'S NPCS
                var NewAnimMgrs : [agent]animation_manager = map{}
                for (EnemyKey -> AnimMgr : AnimationManagers):
                    var KeepThis : logic = true
                    for (Enemy : State.Enemies):
                        if (Enemy.Agent = EnemyKey):
                            set KeepThis = false
                    if (KeepThis?):
                        if (set NewAnimMgrs[EnemyKey] = AnimMgr) {}
                set AnimationManagers = NewAnimMgrs
    
                # Remove UI
                if (UI := State.KingUIContainer?):
                    if (PlayerUI := GetPlayerUI[Player]):
                        PlayerUI.RemoveWidget(UI)
                if (RoundUI := State.RoundUI?):
                    if (PlayerUI := GetPlayerUI[Player]):
                        PlayerUI.RemoveWidget(RoundUI)
    
                # ✅ CLEAR BILLBOARD WHEN PLAYER LEAVES
                State.Config.KingBillboard.SetText(StringToMessage("Empty"))
    
                # Remove from States map
                var NewStates : [agent]player_state = map{}
                for (Key -> Value : States):
                    if (Key <> Agent):
                        if (set NewStates[Key] = Value) {}
                set States = NewStates

                # ✅ RE-SPAWN JOIN PLOT PROP FOR THAT CONFIG
                if (OldState := States[Agent]):
                    # ✅ MARK CONFIG AS NO LONGER OCCUPIED
                    set OldState.Config.IsOccupied = false
                    set OldState.Config.OccupiedByAgent = false
                    
                    # ✅ ENABLE THE SELECTOR AGAIN
                    OldState.Config.Selector.Enable()
                    Print("🔥 SELECTOR RE-ENABLED")
                    
                    SpawnJoinPlotProp(OldState.Config)
            
                # Remove from PlayerToAgent map   
                var NewPlayerToAgent : [player]agent = map{}
                for (Key -> Value : PlayerToAgent):
                    if (Key <> Player):
                        if (set NewPlayerToAgent[Key] = Value) {}
                set PlayerToAgent = NewPlayerToAgent
                
                Print("PLAYER CLEANUP COMPLETE")

    MakeUsernameMessage<localizes>(Plr : player) : message =
        "{Plr}"
    
    UpdateConfigBillboard(Cfg : player_config, Agent : agent) : void =
        if (P := player[Agent], P.IsActive[]):
            Cfg.KingBillboard.SetText(MakeUsernameMessage(P))
        else:
            Cfg.KingBillboard.SetText(StringToMessage("Empty"))

    DelayedTeleport(Agent : agent, Cfg : player_config)<suspends> : void =
        Sleep(0.3)
        Cfg.ConfigTeleporter.Teleport(Agent)

    InitializeEvents() : void =
        for(Event : AllEvents):
            set Event.TDController = Self
            Event.StartEventTrigger.TriggeredEvent.Subscribe(Event.StartEvent)

    ReturnRarity(RarityName : string) : ?CustomRarity =
        for(Rarity : Rarities):
            if(Rarity.Name = RarityName):
                return option{Rarity}
        return false

    CleanupPlacementSpot(Spot:defense_placement_spot):void =
        # Reset spot state
        set Spot.IsOccupied = false
        set Spot.PlacedDefender = false
        set Spot.PlacedDefenderArrayIndex = -1
        set Spot.CurrentUpgradeCost = 0.0
        
        # Reset buttons
        Spot.PlacementButton.Enable()
        Spot.UpgradeButton.Disable()

    SelectEnemyType(Cfg : player_config) : ?tuple(int, ?CustomVariant) =
        Print("⚠️ RARITIES ARRAY LENGTH: {Rarities.Length}")
        # Build an enemy pool and a parallel index pool that maps back to the original Cfg.Attackers indices
        var EnemyPool : []enemy_type = Cfg.Attackers
        var EnemyIndexPool : []int = array{}
        for (Idx := 0..Cfg.Attackers.Length - 1):
            set EnemyIndexPool += array{Idx}
        
        # If an event restricts enemies, filter both the enemies and the index mapping together
        if(CE := CurrentEvent?):
            if(AllowedEnemies := CE.OnlyAllowCertainEnemies?):
                var FilteredEnemies : []enemy_type = array{}
                var FilteredIndices : []int = array{}
                for (Idx := 0..Cfg.Attackers.Length - 1):
                    if (AllowedEnemies.Find["{Idx}"]):
                        if (Atk := Cfg.Attackers[Idx]):
                            set FilteredEnemies += array{Atk}
                            set FilteredIndices += array{Idx}
                if(FilteredEnemies.Length > 0):
                    set EnemyPool = FilteredEnemies
                    set EnemyIndexPool = FilteredIndices
                else:
                    return false
        
        # Pick rarity from the current pool
        MaybeRarity := GetRarity(EnemyPool)
        if (SelectedRarity := MaybeRarity?):
            var AvailableOriginalIdxs: []int = array{}
            
            for (PoolIdx := 0..EnemyPool.Length - 1):
                if (Enemy := EnemyPool[PoolIdx]):
                    if (Enemy.Rarity = SelectedRarity.Name):
                        if (RequiredEvent := Enemy.RequireEvent?):
                            if (TheCurrentEvent := CurrentEvent?, TheCurrentEvent.EventName = RequiredEvent):
                                if (OriginalIdx := EnemyIndexPool[PoolIdx]):
                                    set AvailableOriginalIdxs += array{OriginalIdx}
                        else:
                            if (OriginalIdx := EnemyIndexPool[PoolIdx]):
                                set AvailableOriginalIdxs += array{OriginalIdx}
            
            if (AvailableOriginalIdxs.Length > 0):
                RandomIndex := GetRandomInt(0, AvailableOriginalIdxs.Length - 1)
                if (SelectedOriginalIdx := AvailableOriginalIdxs[RandomIndex]):
                    MaybeVariant := GetVariant()
                    return option{ (SelectedOriginalIdx, MaybeVariant) }
        
        return false
        

    GetRarity(EnemyPool : []enemy_type) : ?CustomRarity =
        # Build list of rarities from enemy pool
        var RarityPoolFromEnemies : []CustomRarity = array{}
        for(Enemy : EnemyPool):
            MaybeR := ReturnRarity(Enemy.Rarity)
            if(R := MaybeR?, not RarityPoolFromEnemies.Find[R]):
                set RarityPoolFromEnemies += array{R}
        
        if(RarityPoolFromEnemies.Length <= 0):
            return false
        
        var RarityPool : []CustomRarity = RarityPoolFromEnemies
        
                # ✅ FILTER BY EVENT OR ROUND CONFIG
        if(CE := CurrentEvent?):
            # Event is active - use event's allowed rarities
            if(OnlyRar := CE.OnlyAllowCertainRarities?):
                var Tmp : []CustomRarity = array{}
                for(R : RarityPoolFromEnemies):
                    if(OnlyRar.Find[R.Name]):
                        set Tmp += array{R}
                if(Tmp.Length <= 0):
                    return false
                set RarityPool = Tmp
        else:
            # No event - filter by round config's AllowedRarities
            var CurrentRoundIndex : int = 0
            for(AgentKey -> State : States):
                set CurrentRoundIndex = State.CurrentRound
            
            # Get the round config and check AllowedRarities
            for(AgentKey -> State : States):
                if(CurrentRoundIndex >= 0, CurrentRoundIndex < State.Config.Rounds.Length):
                    if(RoundCfg := State.Config.Rounds[CurrentRoundIndex]):
                        if(RoundCfg.AllowedRarities.Length > 0):
                            # Filter to only allowed rarities for this round
                            var FilteredByRound : []CustomRarity = array{}
                            for(R : RarityPoolFromEnemies):
                                if(RoundCfg.AllowedRarities.Find[R.Name]):
                                    set FilteredByRound += array{R}
                            
                            if(FilteredByRound.Length > 0):
                                set RarityPool = FilteredByRound
                            else:
                                return false  # No matching rarities for this round
        
        # ✅ CALCULATE WEIGHTED CHANCES (with optional boost)
        var EffChances : []float = array{}
        var Total : float = 0.0
        var BoostOn : logic = false
        var BoostThreshold : float = 0.0
        
        if(CE := CurrentEvent?):
            if(BR := CE.BoostRarities?):
                set BoostOn = true
                set BoostThreshold = BR
        
        for(R : RarityPool):
            var W : float = R.Chance
            if(BoostOn?):
                if(W >= BoostThreshold):
                    set W *= 1.25
                else:
                    set W *= 0.85
            if(W < 0.0):
                set W = 0.0
            set EffChances += array{W}
            set Total += W
        
        if(Total <= 0.0):
            return false
        
        # ✅ WEIGHTED RANDOM SELECTION
        Pick := GetRandomFloat(0.0, Total)
        var Run : float = 0.0
        for(idx -> W : EffChances):
            set Run += W
            if(Pick <= Run):
                return option{RarityPool[idx]}
        
        return option{RarityPool[RarityPool.Length - 1]}

    GetVariant() : ?CustomVariant =
        var VariantPool : []CustomVariant = Variants
        if(ACurrentEvent := CurrentEvent?):
            if(NewVariantList := ACurrentEvent.OnlyAllowCertainVariants?):
                set VariantPool = array{}
                for(Vari : Variants):
                    if(NewVariantList.Find[Vari.Name]):
                        set VariantPool += array{Vari}
                if(VariantPool.Length <= 0):
                    set VariantPool = Variants
        var Weights : []float = array{}
        var TotalWeight : float = 0.0
        var HasBoost : logic = false
        var BoostThreshold : float = 0.0
        if(ACurrentEvent := CurrentEvent?):
            if(BV := ACurrentEvent.BoostVariants?):
                set HasBoost = true
                set BoostThreshold = BV
        for(V : VariantPool):
            var Base : float = V.Chance
            if(HasBoost?):
                if(Base >= BoostThreshold):
                    set Base *= 1.25
                else:
                    set Base *= 0.85
            if(Base < 0.0):
                set Base = 0.0
            set Weights += array{Base}
            set TotalWeight += Base
        if(TotalWeight <= 0.0):
            RandomIndex := GetRandomInt(0, VariantPool.Length - 1)
            return option{VariantPool[RandomIndex]}
        Pick := GetRandomFloat(0.0, TotalWeight)
        var Running : float = 0.0
        for(idx -> W : Weights):
            set Running += W
            if(Pick <= Running):
                if(VariantPool[idx].Name = "None"):
                    return false
                else:
                    return option{VariantPool[idx]}
        return option{VariantPool[0]}

    ShowRouteSelectionUI(Agent:agent, IsSwitching:logic)<suspends>:void =
        if (State := States[Agent], P := player[Agent], PlayerUI := GetPlayerUI[P]):
            if (not P.IsActive[]): 
                return
            Cfg := State.Config
            UIConfig := Cfg.RouteSelectionUIConfig
            
            if (IsSwitching?, State.GameRunning = true):
                Cfg.CannotSwitchDuringGameMessage.Show(Agent)
                return
            
            QuestionBlock := text_block{
                DefaultText := StringToMessage(UIConfig.QuestionText),
                DefaultTextColor := NamedColors.White,
                DefaultTextSize := 28.0
            }
            
            var RouteButtons : []widget = array{}
            for (RouteIdx := 0..Cfg.KingRoutes.Length - 1):
                if (Route := Cfg.KingRoutes[RouteIdx]):
                    RouteBtn := button_loud{DefaultText := StringToMessage(Route.RouteName)}
                    
                    BtnHandler := route_selection_button_handler{
                        Controller := Self,
                        Agent := Agent,
                        RouteIndex := RouteIdx
                    }
                    RouteBtn.OnClick().Subscribe(BtnHandler.OnButtonClicked)
                    
                    set RouteButtons += array{RouteBtn}
            
            var ButtonSlots : []stack_box_slot = array{}
            for (Btn : RouteButtons):
                set ButtonSlots += array{stack_box_slot{
                    Widget := Btn,
                    Padding := margin{Bottom := 10.0}
                }}
            
            ButtonStack := stack_box{
                Orientation := orientation.Vertical,
                Slots := ButtonSlots
            }
            
            Background := texture_block{
                DefaultImage := UIConfig.BackgroundTexture,
                DefaultDesiredSize := UIConfig.BackgroundSize
            }
            
            MainPanel := overlay{
                Slots := array{
                    overlay_slot{Widget := Background},
                    overlay_slot{
                        Widget := QuestionBlock,
                        HorizontalAlignment := horizontal_alignment.Center,
                        VerticalAlignment := vertical_alignment.Top,
                        Padding := margin{Top := 40.0}
                    },
                    overlay_slot{
                        Widget := ButtonStack,
                        HorizontalAlignment := horizontal_alignment.Center,
                        VerticalAlignment := vertical_alignment.Center
                    }
                }
            }
            
            UICanvas := canvas{
                Slots := array{
                    canvas_slot{
                        Widget := MainPanel, Anchors := anchors{Minimum := vector2{X:=0.5, Y:=0.5}, Maximum := vector2{X:=0.5, Y:=0.5}},
                        Alignment := vector2{X := 0.5, Y := 0.5},
                        SizeToContent := true
                    }
                }
            }

            PlayerUI.AddWidget(UICanvas, player_ui_slot{InputMode := ui_input_mode.All})
            set State.RouteSelectionUICanvas = option{UICanvas}
            set State.WaitingForRouteSelection = true

    HideRouteSelectionUI(Agent:agent):void =
        if (State := States[Agent], P := player[Agent], PlayerUI := GetPlayerUI[P]):
            if (not P.IsActive[]): 
                return
            if (UI := State.RouteSelectionUICanvas?):
                PlayerUI.RemoveWidget(UI)
                set State.RouteSelectionUICanvas = false
                set State.WaitingForRouteSelection = false   

    OnRouteSelected(Agent:agent, RouteIndex:int)<suspends>:void =
        if (P := player[Agent], not P.IsActive[]): 
            return
        if (State := States[Agent], Cfg := State.Config):
            Print("ROUTE {RouteIndex} SELECTED")
            
            HideRouteSelectionUI(Agent)
            
            var IsSwitching : logic = false
            if (State.SelectedKingRoute >= 0):
                set IsSwitching = true
                
                if (set State.KingRouteProgress[State.SelectedKingRoute] = State.CurrentRebirthLevel) {}
                Print("SAVED ROUTE {State.SelectedKingRoute} PROGRESS: REBIRTH {State.CurrentRebirthLevel}")
                # ADD THESE LINES AFTER: if (set State.KingRouteProgress[State.SelectedKingRoute] = State.CurrentRebirthLevel) {}
                if (P := player[Agent]):
                    TDPersistenceManager.UpdateKingRouteProgress(P, State.SelectedKingRoute, State.CurrentRebirthLevel)
            
            set State.SelectedKingRoute = RouteIndex
                # ADD THIS LINE AFTER: set State.SelectedKingRoute = RouteIndex
            if (P := player[Agent]):
                TDPersistenceManager.UpdateSelectedKingRoute(P, RouteIndex)
            
            var LoadedRebirthLevel : int = 0
            if (SavedProgress := State.KingRouteProgress[RouteIndex]):
                set LoadedRebirthLevel = SavedProgress
            set State.CurrentRebirthLevel = LoadedRebirthLevel
            Print("LOADED ROUTE {RouteIndex} PROGRESS: REBIRTH {LoadedRebirthLevel}")

            # ADD THESE LINES AFTER: set State.CurrentRebirthLevel = LoadedRebirthLevel
            if (P := player[Agent]):
                TDPersistenceManager.UpdateKingRouteProgress(P, RouteIndex, LoadedRebirthLevel)
            
            if (RouteIndex >= 0, RouteIndex < Cfg.KingRoutes.Length):
                if (Route := Cfg.KingRoutes[RouteIndex]):
                    # ✅ SHRINK OLD UI IF SWITCHING
                    if (IsSwitching?):
                        if (P := player[Agent], PlayerUI := GetPlayerUI[P]):
                            if (OldUI := State.KingUIContainer?):
                                spawn{ShrinkUIOut(PlayerUI, OldUI, 0.3)}
                                Sleep(0.3)
                            set State.KingUIContainer = false
                            set State.KingHealthBar = false
                            set State.KingHealthText = false
                    
                    SpawnKingForRoute(Agent, Route)

                    if (LoadedRebirthLevel >= 0, LoadedRebirthLevel < Route.RouteRebirths.Length):
                        if (StartingRebirth := Route.RouteRebirths[LoadedRebirthLevel]):
                            for (PropIdx := 0..StartingRebirth.RebirthPropAssets.Length - 1):
                                if (PropAsset := StartingRebirth.RebirthPropAssets[PropIdx]):
                                    var PropTransform : transform = transform{}
                                    if (PropIdx < StartingRebirth.RebirthPropTransforms.Length):
                                        if (SavedTransform := StartingRebirth.RebirthPropTransforms[PropIdx]):
                                            set PropTransform = FixTransform(SavedTransform)
                                    
                                    PropResult := SpawnProp(PropAsset, PropTransform.Translation, PropTransform.Rotation)
                                    if (NewProp := PropResult(0)?):
                                        NewProp.Show()
                                        set State.CurrentRebirthProps += array{NewProp}
                    
                    if (IsSwitching?):
                        # ✅ ADD NEW UI WITH GROW ANIMATION
                        Sleep(0.1)
                        AddKingUIWithAnimation(Agent, Route.InitialKing.CharacterName, State.KingHealth, State.CurrentKingMaxHealth)
                        RespawnDefenders(Agent)

    SpawnKingForRoute(Agent:agent, Route:king_route)<suspends>:void =
        if (P := player[Agent], not P.IsActive[]): 
            return
        if (State := States[Agent]):
            Print("SPAWNING KING FOR ROUTE")
            
            if (OldKing := State.CurrentKingProp?):
                Print("DISPOSING OLD KING")
                if (OldKing.IsValid[]):
                    AnimateDefenderScale(OldKing, 1.0, 0.0, 0.5)
                    Sleep(0.5)
                    OldKing.Dispose()
            
            var CurrentKingVariant : king_variant = king_variant{}
            var BaseHealth : float = Route.InitialKing.MaxHealth
            var KingPropAsset : creative_prop_asset = Route.InitialKing.PropAsset
            var KingScale : vector3 = vector3{X:=1.0, Y:=1.0, Z:=1.0}
            
            Print("REBIRTH LEVEL: {State.CurrentRebirthLevel}")
            if (State.CurrentRebirthLevel > 0):
                if (State.CurrentRebirthLevel <= Route.RouteRebirths.Length):
                    if (RebirthCfg := Route.RouteRebirths[State.CurrentRebirthLevel - 1]):
                        Print("USING REBIRTH VARIANT")
                        set CurrentKingVariant = RebirthCfg.KingVariant
                        set BaseHealth = Route.InitialKing.MaxHealth * CurrentKingVariant.MaxHealthMultiplier
                        set KingPropAsset = CurrentKingVariant.PropAsset
                        set KingScale = CurrentKingVariant.PropScale
            
            FixedTransform := FixTransform(Route.InitialKing.Location)
            
            Print("SPAWNING KING PROP AT: X={FixedTransform.Translation.X}, Y={FixedTransform.Translation.Y}, Z={FixedTransform.Translation.Z}")

            Result := SpawnProp(KingPropAsset, FixedTransform.Translation, FixedTransform.Rotation)
            if (NewKingProp := Result(0)?):
                Print("KING PROP SPAWNED SUCCESSFULLY")
                
                NewKingProp.Show()
                Print("KING PROP SHOWN")
                
                if(NewKingProp.TeleportTo[FixedTransform]) {}
                
                if (State.CurrentKingProp?):
                    if(NewKingProp.TeleportTo[transform{
                        Translation := FixedTransform.Translation,
                        Rotation := FixedTransform.Rotation,
                        Scale := vector3{X:=0.01, Y:=0.01, Z:=0.01}
                    }]) {}
                    Sleep(0.05)
                    AnimateDefenderScale(NewKingProp, 0.01, KingScale.X, 0.8)
                
                set State.CurrentKingProp = option{NewKingProp}
                set State.CurrentKingMaxHealth = BaseHealth
                set State.KingHealth = BaseHealth

                # ✅ ADD KING AS A SPECIAL "DEFENDER" SO ATTACKERS TREAT IT NORMALLY
                KingDefense := defense_unit{
                    Prop := NewKingProp,
                    Health := BaseHealth,
                    DefenderTypeIndex := -1,
                    CurrentVariantLevel := 0,
                    MaybeVariant := false,
                    SecondaryProp := false  # ✅ ADD THIS
                }
                set State.Defenses += array{KingDefense}
                
                Print("KING SPAWNED - Health: {BaseHealth}, MaxHealth: {State.CurrentKingMaxHealth}")
                UpdateKingHealthUI(State)
                
                # ✅ NEW: SPAWN KING HP BAR IF ENABLED
                if (Route.InitialKing.EnableHealthBar?):
                    # Dispose old HP bar if it exists
                    if (OldHPBar := State.KingHealthBarProp?):
                        if (OldHPBar.IsValid[]):
                            OldHPBar.Dispose()
                    
                    HPSettings := Route.InitialKing.HealthBarSettings
                    KingPos := NewKingProp.GetTransform().Translation
                    
                    # ✅ SPAWN WITH FACE-UP ROTATION
                    FaceUpRotation := MakeRotation(vector3{X:=1.0, Y:=0.0, Z:=0.0}, DegreesToRadians(-90.0))
                    
                    HPBarResult := SpawnProp(HPSettings.Prop, KingPos + vector3{Z := HPSettings.ZOffset * 1.0}, FaceUpRotation)
                    if (HPBarProp := HPBarResult(0)?):
                        HPBarProp.Show()
                        
                        # ✅ SET SCALE AFTER SPAWNING
                        InitialTransform := transform{
                            Translation := KingPos + vector3{Z := HPSettings.ZOffset * 1.0},
                            Rotation := FaceUpRotation,
                            Scale := HPSettings.PropScale  # ✅ NOW THIS WORKS
                        }
                        if (HPBarProp.TeleportTo[InitialTransform]) {}
                        
                        set State.KingHealthBarProp = option{HPBarProp}
                        spawn{FollowKingWithHPBar(NewKingProp, HPBarProp, HPSettings, State)}
                        Print("✅ KING HP BAR SPAWNED WITH SCALE: {HPSettings.PropScale}")
            else:
                Print("FAILED TO SPAWN KING PROP!")
