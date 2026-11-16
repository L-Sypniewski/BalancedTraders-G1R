// EconomyProbe — IngameTools panel that measures the game's native
// per-unit sell-price curve for a tracked item class, and can stock the
// player up with test items so a measurement session needs no grinding.
//
// Usage:
//   1. Launch with -ingametools (mods: EconomyProbe), open Ingame Tools
//      -> "Economy" -> "Sell Curve Probe".
//   2. Pick/enter the item to measure (presets or class name).
//   3. "Give 50" to stock up. Find a trader with plenty of ore.
//   4. Sell EXACTLY ONE unit per trade acceptance, repeatedly, to the same
//      trader. The panel samples ore + item count every frame and records
//      the ore gained per unit sold.
//   5. "Copy CSV" -> paste anywhere. The n-th ore delta is the marginal
//      price of the n-th unit (the native saturation curve of that
//      trader/region/session, including its category modifier).
//
// Fitting hints: plot P_n/P_1 against n (geometric decay => straight line
// on a log axis; a flattening floor => the WorldDefinition multiplier
// clamps). Repeat with a different trader type to separate category
// modifiers from saturation.

#if WITH_IMGUI

class UEconomyProbeTool : UIngameTool
{
	default Category = "Economy";
	default MenuPath = "Economy.Sell Curve Probe";
	default Title = "Sell Curve Probe";
	default bIsWindowOpen = false;

	// Tracked item class (default: shadowbeast teeth, base value 25).
	UPROPERTY()
	TSubclassOf<UItemDefinition> TrackedItemClass;
	default TrackedItemClass = UItAt_Shadow_03::StaticClass();

	bool bWatching = true;
	FString ClassNameInput = "ItAt_Shadow_03";

	int LastOre = -1;
	int LastUnits = -1;
	int PendingUnitsSold = 0;
	int PendingOreGained = 0;

	// Observation rows: cumulative units sold | ore gained in that step.
	TArray<int> UnitMarks;
	TArray<int> OreDeltas;

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

		int UnitsDelta = LastUnits - Units;   // >0: units sold
		int OreDelta = Ore - LastOre;         // >0: ore received

		if (UnitsDelta > 0)
		{
			// Units left the inventory: open/extend a measurement step. The
			// ore may arrive in the same or the next frame, so keep the step
			// pending until the ore balance settles for one frame.
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
		ImGui::TextDisabled("Sell exactly ONE unit per trade for clean per-unit rows.");
		ImGui::Separator();

		FString ItemName = IsValid(TrackedItemClass.Get())
			? TrackedItemClass.Get().Name.ToString()
			: FString("<invalid>");
		ImGui::InputText("Tracked item", ItemName, ImGuiInputTextFlags::ReadOnly);
		ImGui::Text(f"base value: {GetTrackedBaseValue()}   ore: {GetPlayerOre()}   units left: {GetTrackedUnits()}");

		ImGui::SeparatorText("Test stock");
		if (ImGui::Button("Give 10"))
			GiveTracked(10);
		ImGui::SameLine();
		if (ImGui::Button("Give 50"))
			GiveTracked(50);
		ImGui::SameLine();
		if (ImGui::Button("Give 200"))
			GiveTracked(200);

		ImGui::SeparatorText("Presets");
		if (ImGui::Button("Shadowbeast teeth (25)"))
			SetTrackedClass(UItAt_Shadow_03::StaticClass(), "ItAt_Shadow_03");
		if (ImGui::Button("Lizard skin (13)"))
			SetTrackedClass(UItAt_Lizard_02::StaticClass(), "ItAt_Lizard_02");
		if (ImGui::Button("Wolf fur (5)"))
			SetTrackedClass(UItAt_Wolf_01::StaticClass(), "ItAt_Wolf_01");
		if (ImGui::Button("Arrows (1)"))
			SetTrackedClass(UItAm_Arrow::StaticClass(), "ItAm_Arrow");

		ImGui::SeparatorText("Custom item class");
		ImGui::InputText("Class name", ClassNameInput);
		ImGui::SameLine();
		if (ImGui::Button("Set"))
		{
			UClass Found = UUClassFunctionLibrary::FindClassFromName(FName(ClassNameInput));
			if (IsValid(Found) && Found.IsChildOf(UItemDefinition::StaticClass()))
			{
				TrackedItemClass = Found;
				ResetSamples();
			}
			else
			{
				ImGui::OpenPopup("ClassNotFound");
			}
		}
		if (ImGui::BeginPopup("ClassNotFound"))
		{
			ImGui::Text("Not a UItemDefinition class name.");
			ImGui::EndPopup();
		}

		ImGui::Separator();
		ImGui::Checkbox("Watch", bWatching);
		ImGui::SameLine();
		if (ImGui::Button("Reset samples"))
			ResetSamples();
		ImGui::SameLine();
		if (ImGui::Button("Copy CSV"))
			ImGui::SetClipboardText(BuildCSV());

		ImGui::SeparatorText("Samples");

		if (UnitMarks.IsEmpty())
		{
			ImGui::TextDisabled("No sales recorded yet.");
			return;
		}

		int First = OreDeltas[0];
		int Base = GetTrackedBaseValue();
		if (UnitMarks[0] > 1)
			ImGui::TextDisabled("first row covers multiple units - per-unit prices combined");

		for (int i = 0; i < UnitMarks.Num(); ++i)
		{
			int Mark = UnitMarks[i];
			int Delta = OreDeltas[i];
			float Ratio = First > 0 ? float(Delta) / float(First) : 0.0f;
			float Mult = Base > 0 ? float(Delta) / float(Base) : 0.0f;
			ImGui::Text(f"unit {Mark}: {Delta} ore   x{Ratio:.2f} of first   x{Mult:.2f} of base");
		}

		ImGui::Separator();
		ImGui::TextDisabled("CSV columns: units_cumulative,ore_delta,ratio_vs_first,ratio_vs_base");
	}

	private FString BuildCSV() const
	{
		FString CSV = "units_cumulative,ore_delta,ratio_vs_first,ratio_vs_base";
		int First = OreDeltas.Num() > 0 ? OreDeltas[0] : 0;
		int Base = GetTrackedBaseValue();
		for (int i = 0; i < UnitMarks.Num(); ++i)
		{
			float R1 = First > 0 ? float(OreDeltas[i]) / float(First) : 0.0f;
			float RB = Base > 0 ? float(OreDeltas[i]) / float(Base) : 0.0f;
			CSV += f"\n{UnitMarks[i]},{OreDeltas[i]},{R1:.3f},{RB:.3f}";
		}
		return CSV;
	}
}

#endif
