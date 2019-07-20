configs = <|
	(* 
	Reference:
	https://en.wikipedia.org/wiki/Regular_4-polytope#Properties_2
	*)

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

	(* cell: icosahedron *)
	"polytope_3_5_52" -> {
		{
			{1, 0, phi, -1/phi	},
			{1, -phi, 1/phi, 0	},
			{0, 1, 0, 0	},
			{1, phi, -1/phi, 0	}
		},
		{0, 0, 0, 1}
	},

	(* cell: {5/2, 5}. Small stellated dodecahedron *)
	"polytope_52_5_3" -> {
		{
			{1, -phi, -1/phi, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{0, 1, 1/phi, phi}
	},

	(* cell: {5, 5/2}. Great dodecahedron. Self dual *)
	"polytope_5_52_5" -> {
		{
			{0, 1, 0, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{0, 1, 1/phi, phi}
	},

	(* cell: {5, 3}. Dodecahedron *)
	"polytope_5_3_52" -> {
		{
			{0, 1, 0, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{1, 1, 1, 1}
	},

	(* cell: great stellated dodecahedron *)
	"polytope_52_3_5" -> {
	},

	(* cell: {5/2, 5}. Small stellated dodecahedron. Self dual *)
	"polytope_52_5_52" -> {
		{
			{1, -phi, -1/phi, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{0, phi, 1, 1/phi}
	},

	(* cell: Great dodecahedron *)
	"polytope_5_52_3" -> {
	},

	(* cell: great icosahedron *)
	"polytope_3_52_5" -> {
	},

	(* cell: tetrahedron, 600 cells *)
	"polytope_3_3_52" -> {
	},

	(* cell: great stellated dodecahedron *)
	"polytope_52_3_3" -> {
	},



	"test" -> {
		{
			{1, 0, phi, -1/phi	},
			{1, -phi, 1/phi, 0	},
			{0, 1, 0, 0	},
			{1, phi, -1/phi, 0	}
		},
		{0, 0, 0, 1}
	},

	"null" -> {}
|>
