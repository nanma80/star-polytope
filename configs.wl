configs = <|
	(* 
	Reference:
	https://en.wikipedia.org/wiki/Regular_4-polytope#Properties_2
	*)

	(* 120-cell *)
	"cell120" -> {
		{
			{0, 1, 0, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{0, 1/phi^2, 1, phi^2}
	},

	(* 600-cell *)
	"cell600" -> {
		{
			{1, 0, phi, -1/phi	},
			{1, -phi, 1/phi, 0	},
			{1, phi, -1/phi, 0	},
			{0, 1, 0, 0	}
		}, 
		{0, 0, 0, 1}
	},

	(* Icosahedral 120-cell. cell: icosahedron *)
	"polytope_3_5_52" -> {
		{
			{1, 0, phi, -1/phi	},
			{1, -phi, 1/phi, 0	},
			{0, 1, 0, 0	},
			{1, phi, -1/phi, 0	}
		},
		{0, 0, 0, 1}
	},

	(* Small stellated 120-cell. cell: {5/2, 5}. Small stellated dodecahedron *)
	"polytope_52_5_3" -> {
		{
			{1, -phi, -1/phi, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{0, 1, 1/phi, phi}
	},

	(* Great 120-cell. cell: {5, 5/2}. Great dodecahedron. Self dual *)
	"polytope_5_52_5" -> {
		{
			{0, 1, 0, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{0, 1, 1/phi, phi}
	},

	(* Grand 120-cell. cell: {5, 3}. Dodecahedron *)
	"polytope_5_3_52" -> {
		{
			{0, 1, 0, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{1, 1, 1, 1}
	},

	(* Great stellated 120-cell. cell: great stellated dodecahedron *)
	"polytope_52_3_5" -> {
	},

	(* Grand stellated 120-cell. cell: {5/2, 5}. Small stellated dodecahedron. Self dual *)
	"polytope_52_5_52" -> {
		{
			{1, -phi, -1/phi, 0	},
			{1, phi, -1/phi, 0	},
			{1, -phi, 1/phi, 0	},
			{1, 0, phi, -1/phi	}
		}, 
		{0, phi, 1, 1/phi}
	},

	(* Great grand 120-cell. cell: Great dodecahedron *)
	"polytope_5_52_3" -> {
	},

	(* Greate icosahedral 120-cell. cell: great icosahedron *)
	"polytope_3_52_5" -> {
	},

	(* Grand 600-cell. cell: tetrahedron, 600 cells *)
	"polytope_3_3_52" -> {
	},

	(* Great grand stellated 120-cell. cell: great stellated dodecahedron *)
	"polytope_52_3_3" -> {
	},



	"test" -> {
		{
			{1, 0, phi, -1/phi	},
			{1, -phi, 1/phi, 0	},
			{0, 1, 0, 0},
			(*{1, 0, -phi, -1/phi	} exhausted all ending with 1/phi and -1/phi*)
			{2, 1, -1/phi, phi}
		},
		(*{-1, -1, -1, -1}*)
		{0, -1, 1/phi, phi}
	},

	"null" -> {}
|>
