// EconomyProbe — IngameTools panel that measures the game's native
// per-unit sell-price curve for a tracked item class, and can stock the
// player up with test items so a measurement session needs no grinding.
//
// Build-102 note: mod scripts get a REDUCED ImGui binding set — e.g.
// ImGui::SeparatorText is NOT available to mods (vanilla IngameTools
// scripts have it, mods don't). Only functions proven by compile-bisection
// are used here: Text, TextDisabled, Separator, Button, Checkbox, SameLine.

class UEconomyProbeTool : UIngameTool
{
	default Category = "Economy";
	default MenuPath = "Economy.Sell Curve Probe";
	default Title = "Sell Curve Probe";
	default bIsWindowOpen = false;

	UPROPERTY()
	TSubclassOf<UItemDefinition> TrackedItemClass;
	default TrackedItemClass = UItAt_Shadow_03::StaticClass();

	bool bWatching = true;
	FString ClassNameInput = "ItAt_Shadow_03";

	int LastOre = -1;
	int LastUnits = -1;
	int PendingUnitsSold = 0;
	int PendingOreGained = 0;

	TArray<int> UnitMarks;
	TArray<int> OreDeltas;

	// Streaming-safe teleport machinery (vanilla cheat-command pattern).
	UCheatCommandWithPartitionStreamingProvider StreamProvider;
	FOnStreamingCompleteDelegate OnStreamed;

	UFUNCTION(BlueprintOverride)
	void Initialize()
	{
		if (!OnStreamed.IsBound())
			OnStreamed.BindUFunction(this, n"HandleStreamComplete");
	}

	UFUNCTION()
	private void HandleStreamComplete(FVector Location)
	{
		UCheatModeHelper::TeleportTo(Location);
	}

	private void SetupTrader(FName TraderUniqueName, FString TraderLabel)
	{
		AGothicCharacterState Trader = AGothicCharacterState::FindByUniqueName(TraderUniqueName);
		if (!IsValid(Trader))
			return;

		Trader.Inventory.AddItemOfClass(UItMi_Orenugget::StaticClass(), 1000);

		FVector Target = Trader.GetActorLocation();
		if (!UCheatModeHelper::CanPlayerTeleport())
			return;

		if (StreamProvider == nullptr)
			StreamProvider = NewObject(this, UCheatCommandWithPartitionStreamingProvider);
		StreamProvider.LoadStreamingMap(OnStreamed, Target);
	}

	private AGothicPlayerState GetPS() const
	{
		return AGothicPlayerState::MainPlayerState;
	}

	private int GetPlayerOre() const
	{
		if (!IsValid(GetPS()))
			return -1;
		return GetPS().Inventory.CountItemsOfClass(UItMi_Orenugget::StaticClass());
	}

	private int GetTrackedUnits() const
	{
		if (!IsValid(GetPS()) || !IsValid(TrackedItemClass.Get()))
			return -1;
		return GetPS().Inventory.CountItemsOfClass(TrackedItemClass);
	}

	private int GetTrackedBaseValue() const
	{
		if (!IsValid(TrackedItemClass.Get()))
			return 0;
		UItemDefinition Def = Cast<UItemDefinition>(TrackedItemClass.Get().DefaultObject);
		return IsValid(Def) ? Def.m_Value : 0;
	}

	private void GiveTracked(int Count)
	{
		if (!IsValid(GetPS()) || !IsValid(TrackedItemClass.Get()))
			return;
		GetPS().Inventory.AddItemOfClass(TrackedItemClass, Count);
	}

	private void SetTrackedClass(TSubclassOf<UItemDefinition> NewClass, FString NewName)
	{
		TrackedItemClass = NewClass;
		ClassNameInput = NewName;
		ResetSamples();
	}

	private void ResetSamples()
	{
		UnitMarks.Reset();
		OreDeltas.Reset();
		PendingUnitsSold = 0;
		PendingOreGained = 0;
		LastOre = -1;
		LastUnits = -1;
	}

	UFUNCTION(BlueprintOverride)
	void DrawImGuiAlways()
	{
		if (!bWatching)
			return;

		int Ore = GetPlayerOre();
		int Units = GetTrackedUnits();
		if (Ore < 0 || Units < 0)
			return;

		if (LastOre < 0 || LastUnits < 0)
		{
			LastOre = Ore;
			LastUnits = Units;
			return;
		}

		int UnitsDelta = LastUnits - Units;
		int OreDelta = Ore - LastOre;

		if (UnitsDelta > 0)
		{
			PendingUnitsSold += UnitsDelta;
			PendingOreGained += OreDelta;
		}
		else if (PendingUnitsSold > 0)
		{
			PendingOreGained += OreDelta;

			if (OreDelta == 0)
			{
				int PreviousMark = UnitMarks.IsEmpty() ? 0 : UnitMarks[UnitMarks.Num() - 1];
				UnitMarks.Add(PreviousMark + PendingUnitsSold);
				OreDeltas.Add(PendingOreGained);
				PendingUnitsSold = 0;
				PendingOreGained = 0;
			}
		}

		LastOre = Ore;
		LastUnits = Units;
	}

	UFUNCTION(BlueprintOverride)
	void DrawImGuiWindow()
	{
		ImGui::Text("Records ore gained per unit sold of the tracked item.");
		ImGui::TextDisabled("Sell exactly ONE unit per trade. Open inventory to free the cursor.");
		ImGui::Separator();

		FString ItemName = IsValid(TrackedItemClass.Get())
			? TrackedItemClass.Get().Name.ToString()
			: FString("<invalid>");
		ImGui::Text(f"item: {ItemName}");
		ImGui::Text(f"base value: {GetTrackedBaseValue()}   ore: {GetPlayerOre()}   units left: {GetTrackedUnits()}");

		ImGui::Separator();
		ImGui::Text("Session setup (+1000 trader ore + teleport):");
		if (ImGui::Button("Cavalorn - Hunter (Wilderness)"))
			SetupTrader(n"UL_STT_Cavalorn_336", "Cavalorn");
		if (ImGui::Button("Wolf - Hunter (New Camp)"))
			SetupTrader(n"NC_ORG_Wolf_855", "Wolf");
		if (ImGui::Button("Cipher - General (New Camp)"))
			SetupTrader(n"NC_ORG_Cipher_873", "Cipher");
		if (ImGui::Button("Dexter - General (Old Camp)"))
			SetupTrader(n"OC_STT_Dexter_329", "Dexter");
		ImGui::SameLine();
		if (ImGui::Button("+1000 ore me"))
		{
			if (IsValid(GetPS()))
				GetPS().Inventory.AddItemOfClass(UItMi_Orenugget::StaticClass(), 1000);
		}

		ImGui::Separator();
		ImGui::Text("Test stock:");
		if (ImGui::Button("Give 10"))
			GiveTracked(10);
		ImGui::SameLine();
		if (ImGui::Button("Give 50"))
			GiveTracked(50);
		ImGui::SameLine();
		if (ImGui::Button("Give 200"))
			GiveTracked(200);

		ImGui::Separator();
		ImGui::Text("Presets:");
		if (ImGui::Button("Shadowbeast teeth (25)"))
			SetTrackedClass(UItAt_Shadow_03::StaticClass(), "ItAt_Shadow_03");
		if (ImGui::Button("Lizard skin (13)"))
			SetTrackedClass(UItAt_Lizard_02::StaticClass(), "ItAt_Lizard_02");
		if (ImGui::Button("Wolf fur (5)"))
			SetTrackedClass(UItAt_Wolf_01::StaticClass(), "ItAt_Wolf_01");
		if (ImGui::Button("Arrows (1)"))
			SetTrackedClass(UItAm_Arrow::StaticClass(), "ItAm_Arrow");

		ImGui::Separator();
		ImGui::Checkbox("Watch", bWatching);
		ImGui::SameLine();
		if (ImGui::Button("Reset samples"))
			ResetSamples();

		ImGui::Separator();
		ImGui::Text("Samples (unit: ore | x-first | x-base):");

		if (UnitMarks.IsEmpty())
		{
			ImGui::TextDisabled("No sales recorded yet.");
			return;
		}

		int First = OreDeltas[0];
		int Base = GetTrackedBaseValue();
		if (UnitMarks[0] > 1)
			ImGui::TextDisabled("first row covers multiple units - prices combined");

		for (int i = 0; i < UnitMarks.Num(); ++i)
		{
			int Mark = UnitMarks[i];
			int Delta = OreDeltas[i];
			float Ratio = First > 0 ? float(Delta) / float(First) : 0.0f;
			float Mult = Base > 0 ? float(Delta) / float(Base) : 0.0f;
			ImGui::Text(f"unit {Mark}: {Delta} ore   x{Ratio:.2f}   x{Mult:.2f}");
		}
	}
}
