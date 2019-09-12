#!/usr/bin/env wolframscript

(*
mogrify -crop 450x450+75+0 -path . pov_*.png
mogrify -crop 300x300+50+0 -path . explode*.gif

magick convert -delay 5 -dispose 2 *.png out.gif
magick convert out.gif -coalesce -duplicate 1,-2-1 -quiet -layers OptimizePlus  -loop 0 cycle.gif
python -m SimpleHTTPServer 8000

*)

(* global config *)

shape = "polytope_3_5_52";

exportToPov = True;
plotAllCells = True;

dataFolder = "data";
imageFolder = "output";

imageSizes = <|
	"allLayers" -> {600, 450}, (* must be 4:3 *)
	"singleLayer" -> {600, 450} (* must be 4:3 *)
|>;

allColors = <|
	"3_3" -> Cyan,
	"5_3" -> Red,
	"3_5" -> Green,
	"52_5" -> Blue,
	"5_52" -> Yellow,
	"52_3" -> Magenta,
	"3_52" -> Orange
|>;

(* shape -> {maxExplosionFactor, frameCount}*)
explosionConfigs = <|
	(* 120-cell *)
	"polytope_5_3_3_cell120" -> {2.0, 30, 1.5},

	(* 600-cell *)
	"polytope_3_3_5_cell600" -> {2.0, 30, 1.5},

	(* Icosahedral 120-cell. cell: icosahedron *)
	"polytope_3_5_52" -> {2.0, 30, 1.5},

	(* Small stellated 120-cell. cell: {5/2, 5}. Small stellated dodecahedron *)
	"polytope_52_5_3" -> {2.0, 30, 1.5},

	(* Great 120-cell. cell: {5, 5/2}. Great dodecahedron. Self dual *)
	"polytope_5_52_5" -> {2.0, 30, 1.5},

	(* Great stellated 120-cell. cell: great stellated dodecahedron *)
	"polytope_52_3_5" -> {2.0, 30, 1.5},

	(* Greate icosahedral 120-cell. cell: great icosahedron *)
	"polytope_3_52_5" -> {2.0, 30, 1.5},




	(* Grand 120-cell. cell: {5, 3}. Dodecahedron *)
	"polytope_5_3_52" -> {1.15, 30, 2.0},

	(* Grand stellated 120-cell. cell: {5/2, 5}. Small stellated dodecahedron. Self dual *)
	"polytope_52_5_52" -> {0.55, 30, 1.5},

	(* Great grand 120-cell. cell: Great dodecahedron *)
	"polytope_5_52_3" -> {0.55, 30, 1.5},

	(* Grand 600-cell. cell: tetrahedron, 600 cells *)
	"polytope_3_3_52" -> {0.85, 30, 2.0},

	(* Great grand stellated 120-cell. cell: great stellated dodecahedron *)
	"polytope_52_3_3" -> {0.16, 30, 1.0}

|>

(* rangeFactor = 1.0; *)

Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

projectTo3d[vertex4d_] := {vertex4d[[1]], vertex4d[[2]], vertex4d[[3]]};
reflect[point_, mirror_] := FullSimplify[point - 2 * (point.mirror)/(mirror.mirror)*mirror];
doubleReflect[point_, mirror1_, mirror2_] := reflect[reflect[point, mirror1], mirror2];
getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
sameVertex[point1_, point2_] := point1 == point2;
sameCenter[edge1_, edge2_] := Total[edge1] == Total[edge2];
sameCellCenter[cell1_, cell2_] := getCellCenter[cell1] == getCellCenter[cell2];
getFaceCenter[face_] := Simplify[Total[face]];
getCellCenter[cell_] := Simplify[Total[Flatten[cell, 1]]];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
explodedCell[cell_, explosionFactor_] := Map[
	(# + Mean[Map[Mean,cell]]*(Norm[First[First[cell]]//N]/Norm[Mean[Map[Mean,cell]]//N])^1.5 * explosionFactor)&, 
	cell, {2}];
getStellatedVertex[a_, b_] := FullSimplify[(b-a)*GoldenRatio^3 + b];
getStellatedFace[face_] := {
	getStellatedVertex[face[[1]], (face[[2]] + face[[3]])/2],
	getStellatedVertex[face[[2]], (face[[3]] + face[[1]])/2],
	getStellatedVertex[face[[3]], (face[[1]] + face[[2]])/2]
};

exportImage[shape_] := Module[
	{
		dataFileName,
		shapeTokens,
		color,
		cellShape,
		cells,
		cellsByLayers,
		layerKeys,
		thickness,
		lighting,
		outputFolder,
		range,
		outputFileName,
		cropCommand,
		inactiveCells,
		inactiveFaces,
		inactiveEdges,
		inactiveVertices,
		activeCells,
		activeFaces,
		touchingIndices,
		notTouchingIndices,
		touchingActiveFaces,
		notTouchingActiveFaces,
		allIndices,
		activeEdges,
		activeVertices,
		graph,
		imageSize
	},

	dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];
	Print["Reading data for " <> shape <> " from " <> dataFileName];
	shapeTokens = StringSplit[shape, "_"];
	If[Length[shapeTokens] < 3,
		color = Red,
		cellShape = shapeTokens[[2]] <> "_" <> shapeTokens[[3]];
		color = allColors[cellShape];
	];


	oldCells = Get[dataFileName];
	Print["There are " <> IntegerString[Length[oldCells]] <> " old cells in total."];


	cells = Map[getStellatedFace, oldCells, {2}];
	Print["There are " <> IntegerString[Length[cells]] <> " (new) cells in total."];

	If[plotAllCells,
		(* doing nothing *) True,
		cells = Select[cells, (getCellCenter[#][[1]] == 0 && getCellCenter[#][[2]] == 0 && getCellCenter[#][[3]] == 0 && getCellCenter[#][[4]] >= 0)&];
	];


	faces = Union[ Flatten[cells, 1], SameTest -> sameCenter];
	edges = Union[ Flatten[Map[getEdgesFromFace, faces], 1], SameTest -> sameCenter];
	vertices = Union[ Flatten[faces,1], SameTest -> sameVertex];

	Print["There are " <> IntegerString[Length[faces]] <> " faces in total."];
	Print["There are " <> IntegerString[Length[edges]] <> " edges in total."];
	Print["There are " <> IntegerString[Length[vertices]] <> " vertices in total."];


	outputFileName = "explore_stellated_" <> shape <> ".png";
	imageFolder = "output";
	If[exportToPov, outputFileName = "pov_" <> outputFileName ];
	If[!plotAllCells, outputFileName = "first_layer_" <> outputFileName ];
	
	outputFileName = FileNameJoin[{imageFolder, shape, outputFileName}];
	imageSize = {600, 450}; (* has to be 4:3 *)
	(*imageSize = {1000, 750};*)
	cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;


	thickness = Norm[cells[[1]][[1]][[1]]] * 0.008;
	lighting = {{"Point", White, {10, -10, 10}}};
	rangeFactor = 0.8;
	range = Norm[cells[[1]][[1]][[1]]] * rangeFactor;

	shapeTokens = StringSplit[shape, "_"];
	If[Length[shapeTokens] < 3,
		color = Red,

		cellShape = shapeTokens[[2]] <> "_" <> shapeTokens[[3]];
		colors = <|
			"3_3" -> Cyan,
			"5_3" -> Red,
			"3_5" -> Green,
			"52_5" -> Blue,
			"5_52" -> Yellow,
			"52_3" -> Magenta,
			"3_52" -> Orange
		|>;
		color = colors[cellShape];
	];

	graph = Graphics3D[
		{
			{
				Opacity[0.5], FaceForm[color], Map[Polygon, Map[projectTo3d, faces, {2}]]
			},
			{
				Opacity[1], FaceForm[White], Map[Cylinder[#, thickness]&, Map[projectTo3d, edges, {2}]]
			},
			{
				Opacity[1], FaceForm[White], Map[Sphere[#, thickness * 2]&, Map[projectTo3d, vertices]]
			}
		},
		ViewPoint -> {3, -3, 5}*3,
		PlotRange -> {{-range, range}, {-range, range}, {-range, range}},
		Lighting -> lighting
	];


	If[exportToPov,
		If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
		POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize, RenderOptions -> "+A0.001 -J +UA"];
		Run[cropCommand];
		,
		Export[outputFileName, graph]
	];
	Print["Saved the image to " <> outputFileName];
]


exportImage["polytope_3_5_52"];


