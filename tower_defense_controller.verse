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

# ✅ FIX: This is the corrected animation_manager that prevents animation stacking
animation_manager := class:
    var IsPlaying : logic = false
    var CurrentDefenderIndex : int = -1
    var CancelEvent : event() = event(){}
    
    StartAnimation(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float, DefenderIndex:int):void =
        # ✅ If attacking a different defender, cancel old animation AND reset IsPlaying flag
        if (DefenderIndex <> CurrentDefenderIndex):
            if (IsPlaying = true):
                CancelEvent.Signal()
                set IsPlaying = false  # ✅ CRITICAL FIX: Reset flag immediately when switching defenders
                set CancelEvent = event(){}
            set CurrentDefenderIndex = DefenderIndex
        
        # Only start if not already playing for THIS defender
        if (IsPlaying = false):
            set IsPlaying = true
            spawn{PlayAnimationAsync(Anim, Seq, AttackInterval)}
    
    CancelAllAnimations():void =
        if (IsPlaying = true):
            CancelEvent.Signal()
            set IsPlaying = false
            set CurrentDefenderIndex = -1
    
    PlayAnimationAsync(Anim:play_animation_controller, Seq:animation_sequence, AttackInterval:float)<suspends>:void =
        race:
            block:
                Anim.PlayAndAwait(Seq)
            block:
                Sleep(AttackInterval)
            block:
                CancelEvent.Await()
        set IsPlaying = false


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
    var EnemyAnimationPlaying : [agent]?logic = map{}  # Global per-NPC animation lock
    var AnimationManagers : [agent]animation_manager = map{}
    var ActiveAttackLoops : [agent]int = map{}
