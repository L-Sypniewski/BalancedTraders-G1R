#if WITH_IMGUI

// EconomyProbe — IngameTools panel that measures the game's native
// per-unit sell-price curve for a tracked item class.
//
// Usage:
//   1. Launch with -ingametools -Mods=EconomyProbe, open the Ingame Tools
//      -> "Economy" -> "Sell Curve Probe".
//   2. Pick the item you are about to sell (default: shadowbeast teeth,
//      base value 25 — a wide, well-measurable price range).
//   3. Sell EXACTLY ONE unit per trade acceptance, repeatedly, to the same
//      trader. The panel samples ore + item count every frame and records
//      the ore gained per unit sold.
//   4. "Copy CSV" and paste anywhere: the n-th row's ore delta is the
//      marginal price of the n-th unit — the native saturation curve for
//      that trader/region/session, which can then be fitted offline.
//
// Detection model (only script-visible data is used):
//   - player ore  = CountItemsOfClass(UItMi_Orenugget)
//   - item units  = CountItemsOfClass(TrackedItemClass)
//   - when units drop by k and ore rises by d, one sale of k units paid d
//     ore in total. Rows with k > 1 are recorded as combined (marked).

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

	int LastOre = -1;
	int LastUnits = -1;
	int PendingUnitsSold = 0;
	int PendingOreGained = 0;

	// Observation rows: cumulative units sold | ore gained in that step.
	TArray<int> UnitMarks;
	TArray<int> OreDeltas;

	private int GetPlayerOre() const
	{
		if (!IsValid(AGothicPlayerState::MainPlayerState))
			return -1;
		return AGothicPlayerState::MainPlayerState.Inventory.CountItemsOfClass(UItMi_Orenugget::StaticClass());
	}

	private int GetTrackedUnits() const
	{
		if (!IsValid(AGothicPlayerState::MainPlayerState))
			return -1;
		return AGothicPlayerState::MainPlayerState.Inventory.CountItemsOfClass(TrackedItemClass);
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

		ImGui::Text(f"ore: {GetPlayerOre()}   units left: {GetTrackedUnits()}");

		ImGui::Checkbox("Watch", bWatching);
		ImGui::SameLine();
		if (ImGui::Button("Reset samples"))
		{
			UnitMarks.Reset();
			OreDeltas.Reset();
			PendingUnitsSold = 0;
			PendingOreGained = 0;
			LastOre = -1;
			LastUnits = -1;
		}
		ImGui::SameLine();
		if (ImGui::Button("Copy CSV"))
		{
			ImGui::SetClipboardText(BuildCSV());
		}

		ImGui::SeparatorText("Samples");

		if (UnitMarks.IsEmpty())
		{
			ImGui::TextDisabled("No sales recorded yet.");
			return;
		}

		int First = OreDeltas[0];
		if (UnitMarks[0] > 1)
			ImGui::TextDisabled("first row covers multiple units - per-unit prices combined");

		for (int i = 0; i < UnitMarks.Num(); ++i)
		{
			int Mark = UnitMarks[i];
			int Delta = OreDeltas[i];
			float Ratio = First > 0 ? float(Delta) / float(First) : 0.0f;
			ImGui::Text(f"unit {Mark}: {Delta} ore   x{Ratio:.2f}");
		}

		ImGui::Separator();
		ImGui::TextDisabled("CSV columns: units_cumulative,ore_delta,ratio_vs_first");
	}

	private FString BuildCSV() const
	{
		FString CSV = "units_cumulative,ore_delta,ratio_vs_first";
		int First = OreDeltas.Num() > 0 ? OreDeltas[0] : 0;
		for (int i = 0; i < UnitMarks.Num(); ++i)
		{
			float Ratio = First > 0 ? float(OreDeltas[i]) / float(First) : 0.0f;
			CSV += f"\n{UnitMarks[i]},{OreDeltas[i]},{Ratio:.3f}";
		}
		return CSV;
	}
}

#endif
