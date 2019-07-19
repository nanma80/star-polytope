configs = <|
	"cell120" -> {
		{
			{0, 1, 0, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{0, 1/phi^2, 1, phi^2}
	},

	"cell600" -> {
		{
			{1, 0, phi, -1/phi	},
			{1, -phi, 1/phi, 0	},
			{1, phi, -1/phi, 0	},
			{0, 1, 0, 0	}
		}, 
		{0, 0, 0, 1}
	},

	"polytope_52_5_3" -> {
		{
			{1, -phi, -1/phi, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{0, 1, 1/phi, phi}
	},

	(* doesn't work. this is only 600-cell *)
	"test" -> {
		{
			{1, 0, phi, -1/phi	},
			{1, -phi, 1/phi, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, -1/phi, 0	}
		}, 
		{0, 0, 0, 1}
	},

	"null" -> {}
|>
