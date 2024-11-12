--- ### _examplecontainer.luau
---
--- example quest container

return {
	examplequest = {
		Name = "Example Quest";
		Desc = "a three-step quest";
		Priority = 0;
		Repeatable = false;

		Steps = {
			--[[ -- example of a folded step to save screen space at the cost of readability
				[0] = {
					Goal = 1; Signals = {  }; Rewards = {  };
					Objective = "";
				};
			--]]
			[1] = {
				Goal = 1;
				Signals = { "A", "B" };
				Rewards = { XP = 50 };
				Objective = "respond to step signals A or B.";
			};
			[2] = {
				Goal = 100;
				Signals = { "C" };
				Rewards = { Mango = 1 };
				Objective = "respond to step signal C.";
			};
			[3] = {
				Goal = 1;
				Signals = { "A" };
				Rewards = { XP = 1000; Mango = 100; };
				Objective = "respond to step signal A";
			};
		};
	};
}