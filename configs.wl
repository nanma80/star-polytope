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

	"polytope_5_52_5" -> {
		{
			{0, 1, 0, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{0, 1, 1/phi, phi}
	},

	"polytope_5_3_52" -> {
		{
			{0, 1, 0, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{1, 1, 1, 1}
	},


	"polytope_52_5_52" -> {
		{
			{1, -phi, -1/phi, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{0, phi, 1, 1/phi}
	},



	"test" -> {
		{
			{1, -phi, -1/phi, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{0, phi, 1, 1/phi}
	},

	"null" -> {}
|>
