#!/usr/bin/env wolframscript

(*
mogrify -crop 450x450+75+0 -path . pov_*.png
mogrify -crop 300x300+50+0 -path . explode*.gif

magick convert -delay 5 -dispose 2 *.png out.gif
magick convert out.gif -coalesce -duplicate 1,-2-1 -quiet -layers OptimizePlus  -loop 0 cycle.gif
python -m SimpleHTTPServer 8000

*)

(* global config *)
exportToPov = True;
dataFolder = "data";
imageFolder = "output";
imageSize = {600, 450}; (* has to be 4:3 *)
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
	"polytope_5_3_3_cell120" -> {2.0, 30},

	(* 600-cell *)
	"polytope_3_3_5_cell600" -> {2.0, 3},

	(* Icosahedral 120-cell. cell: icosahedron *)
	"polytope_3_5_52" -> {2.0, 3},

	(* Small stellated 120-cell. cell: {5/2, 5}. Small stellated dodecahedron *)
	"polytope_52_5_3" -> {2.0, 3},

	(* Great 120-cell. cell: {5, 5/2}. Great dodecahedron. Self dual *)
	"polytope_5_52_5" -> {2.0, 3},

	(* Grand 120-cell. cell: {5, 3}. Dodecahedron *)
	"polytope_5_3_52" -> {2.0, 3},

	(* Great stellated 120-cell. cell: great stellated dodecahedron *)
	"polytope_52_3_5" -> {2.0, 3},

	(* Grand stellated 120-cell. cell: {5/2, 5}. Small stellated dodecahedron. Self dual *)
	"polytope_52_5_52" -> {2.0, 3},

	(* Great grand 120-cell. cell: Great dodecahedron *)
	"polytope_5_52_3" -> {2.0, 3},

	(* Greate icosahedral 120-cell. cell: great icosahedron *)
	"polytope_3_52_5" -> {2.0, 3},

	(* Grand 600-cell. cell: tetrahedron, 600 cells *)
	"polytope_3_3_52" -> {2.0, 3},

	(* Great grand stellated 120-cell. cell: great stellated dodecahedron *)
	"polytope_52_3_3" -> {2.0, 3},

	"test" -> {2.0, 3}
|>

rangeFactor = 1.5;

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
explodedCell[cell_, explosionFactor_] := Map[(# + Mean[Map[Mean,cell]] * explosionFactor)&, cell, {2}];
exportImage[shape_, activeLayer_, explosionFactor_, serialNumber_] := Module[
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
		graph
	},

	dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];
	Print["Reading data for " <> shape <> " from " <> dataFileName];
	shapeTokens = StringSplit[shape, "_"];
	If[Length[shapeTokens] < 3,
		color = Red,
		cellShape = shapeTokens[[2]] <> "_" <> shapeTokens[[3]];
		color = allColors[cellShape];
	];


	cells = Get[dataFileName];
	Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];

	cellsByLayers = GroupBy[cells, getCellCenter[#][[4]]&];
	layerKeys = Sort[Keys[cellsByLayers], Greater];
	Print["There are " <> IntegerString[Length[layerKeys]] <> " layers in total. Layer keys:"];
	Print[N[layerKeys]];

	thinkness = Norm[cells[[1]][[1]][[1]]] * 0.008;
	lighting = {{"Point", White, {10, -10, 10}}};
	range = Norm[cells[[1]][[1]][[1]]] * rangeFactor;

	outputFolder = shape <> "_layer_" <> IntegerString[activeLayer];
	outputFolder = FileNameJoin[{imageFolder, outputFolder}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];

	outputFileName = "animation_" <> shape <> "_layer_" <> IntegerString[activeLayer] <> "_" <> IntegerString[serialNumber, 10, 4] <> ".png";
	If[exportToPov, outputFileName = "pov_" <> outputFileName ];
	outputFileName = FileNameJoin[{outputFolder, outputFileName}];
	cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

	inactiveCells = Apply[Join, Table[cellsByLayers[layerKeys[[k]]], {k, 1, activeLayer - 1}]];
	Print["Selected " <> IntegerString[Length[inactiveCells]] <> " inactive cells."];

	inactiveFaces = Union[ Flatten[inactiveCells, 1], SameTest -> sameCenter];
	inactiveEdges = Union[ Flatten[Map[getEdgesFromFace, inactiveFaces], 1], SameTest -> sameCenter];
	inactiveVertices = Union[ Flatten[inactiveFaces,1], SameTest -> sameVertex];

	activeCells = cellsByLayers[layerKeys[[activeLayer]]];
	Print["Selected " <> IntegerString[Length[activeCells]] <> " active cells."];

	(* before explosion *)
	(*
	activeFaces = Flatten[activeCells, 1];
	allIndices = Table[k, {k, 1, Length[activeFaces]}];
	touchingIndices = Select[ allIndices, ContainsAny[inactiveFaces, {activeFaces[[#]]}, SameTest -> sameCenter]&];
	notTouchingIndices = Complement[allIndices, touchingIndices];
	*)
	(* explosion *)
	activeCells = Map[explodedCell[#, explosionFactor]&, activeCells];

	(* after explosion *)
	activeFaces = Flatten[activeCells, 1];
	activeEdges = Union[ Flatten[Map[getEdgesFromFace, activeFaces], 1], SameTest -> sameCenter];
	activeVertices = Union[ Flatten[activeFaces,1], SameTest -> sameVertex];

	(*
	touchingActiveFaces = Map[activeFaces[[#]]&, touchingIndices];
	notTouchingActiveFaces = Map[activeFaces[[#]]&, notTouchingIndices];
	Print["There are " <> IntegerString[Length[touchingActiveFaces]] <> " faces in the active cells that will touch the inactive cells."];
	*)

	graph = Graphics3D[
		{
			{
				Opacity[0.9], FaceForm[Darker[color, 0.5]], Map[Polygon, Map[projectTo3d, inactiveFaces, {2}]]
			},
			{
				FaceForm[White], Map[Cylinder[#, thinkness]&, Map[projectTo3d, inactiveEdges, {2}]]
			},
			{
				FaceForm[White], Map[Sphere[#, thinkness * 2]&, Map[projectTo3d, inactiveVertices]]
			},

			(*
			{
				Opacity[0.9], FaceForm[Gray], Map[Polygon, Map[projectTo3d, touchingActiveFaces, {2}]]
			},
			{
				Opacity[0.4], FaceForm[Lighter[color, 0.3]], Map[Polygon, Map[projectTo3d, notTouchingActiveFaces, {2}]]
			},
			*)

			{
				Opacity[0.4], FaceForm[Lighter[color, 0.3]], Map[Polygon, Map[projectTo3d, activeFaces, {2}]]
			},
			{
				FaceForm[White], Map[Cylinder[#, thinkness]&, Map[projectTo3d, activeEdges, {2}]]
			},
			{
				FaceForm[White], Map[Sphere[#, thinkness * 2]&, Map[projectTo3d, activeVertices]]
			}
		},
	(*	ViewPoint -> vertices[[7]] * 3, *)
		PlotRange -> {{-range, range}, {-range, range}, {-range, range}},
		Lighting -> lighting
	];


	If[exportToPov,
		If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
		POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize, RenderOptions -> "+A0.001 -J +UA"];
		Run[cropCommand];
		,
		Export[outputFileName, graph];
	]
	Print["Saved the image to " <> outputFileName];
]

(* 
shape = "test";
shape = "polytope_5_3_3_cell120";
shape = "polytope_3_3_5_cell600";
shape = "polytope_3_5_52";
shape = "polytope_52_5_3";
shape = "polytope_5_52_5";
shape = "polytope_5_3_52";
shape = "polytope_52_3_5";
shape = "polytope_52_5_52";
shape = "polytope_5_52_3";
shape = "polytope_3_52_5";
shape = "polytope_3_3_52";
shape = "polytope_52_3_3";
*)

shape = "polytope_5_3_3_cell120";

If[
	StringContainsQ[shape, "polytope_3_3_"],
	activeLayerMin = 1; activeLayerMax = 8,
	activeLayerMin = 2; activeLayerMax = 5
]


For[activeLayer = activeLayerMin, activeLayer <= activeLayerMax, activeLayer ++, 
	Print["activeLayer: " <> IntegerString[activeLayer] <> " in [" <> IntegerString[activeLayerMin] <> ", " <>  IntegerString[activeLayerMax] <> "]"];
	outputFolder = shape <> "_layer_" <> IntegerString[activeLayer];
	outputFolder = FileNameJoin[{imageFolder, outputFolder}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];
	gifFileName = shape <> "_layer_" <> IntegerString[activeLayer];

	explosionConfig = explosionConfigs[shape];
	maxExplosionFactor = explosionConfig[[1]];
	frameCount = explosionConfig[[2]];
	explodeStep = maxExplosionFactor/frameCount;

	explosionFactors = Join[Table[0.001, {k, Ceiling[frameCount / 6]}], Table[k, {k, 0.001, maxExplosionFactor, explodeStep}]];
	For[ frameIndex = 1, frameIndex <= Length[explosionFactors] , frameIndex++,
		Print["Frame #" <> IntegerString[frameIndex] <> "/" <> IntegerString[Length[explosionFactors]]];
		explosionFactor = explosionFactors[[frameIndex]];
		exportImage[shape, activeLayer, explosionFactor, frameIndex];
	];

	gifCommand = "magick convert -duplicate 1,-2-1 -quiet -loop 0 -delay " <> IntegerString[Floor[150/frameCount]] <> " -dispose 2 " <> outputFolder <> "\\*animation*.png " <> imageFolder <> "\\" <> gifFileName <> ".gif";

	Print[gifCommand];
	Run[gifCommand];

]

