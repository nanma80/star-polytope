#!/usr/bin/env wolframscript


shapes = {
	(* "test", *)
	"polytope_5_3_3_cell120",
	"polytope_3_3_5_cell600",
	"polytope_3_5_52",
	"polytope_52_5_3",
	"polytope_5_52_5",
	"polytope_5_3_52",
	"polytope_52_3_5",
	"polytope_52_5_52",
	"polytope_5_52_3",
	"polytope_3_52_5",
	"polytope_3_3_52",
	"polytope_52_3_3"
};

(* shapes = {
	"test"
}; *)


dataFolder = "data";
cuttingDepth = 0.3;

exportToPov = True;


Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

getProjectionMatrix[direction_] := Simplify[Orthogonalize[{direction, {2, -1.4, 0.3, 0.9}, {0, 1, 2.3, 0.8}, {0.5, 0.3, 1, 0.1}}]][[2;;4]];
projectToDirection[vertex4d_, projectionMatrix_] := projectionMatrix.vertex4d;
projectTo3d[vertex4d_] := {vertex4d[[1]], vertex4d[[2]], vertex4d[[3]]};
reflect[point_, mirror_] := FullSimplify[point - 2 * (point.mirror)/(mirror.mirror)*mirror];
doubleReflect[point_, mirror1_, mirror2_] := reflect[reflect[point, mirror1], mirror2];
getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
sameVertex[point1_, point2_] := point1 == point2;
sameCenter[edge1_, edge2_] := Total[edge1] == Total[edge2];
sameCellCenter[cell1_, cell2_] := getCellCenter[cell1] == getCellCenter[cell2];
getCellCenter[cell_] := Total[Flatten[cell, 1]];
getSectionEdge[centeredVertex_, face_, depth_] := Module[
	{face1},
	face1 = RotateLeft[face, SelectFirst[Table[k, {k, Length[face]}], face[[#]] == centeredVertex &] -1];
	Map[ ( 1 - depth) * centeredVertex + depth * face1[[#]] &, {2, -1}]
];

getSectionEdges[centeredVertex_, cell_, depth_] := Module[
	{cellFaces},
	cellFaces = Select[cell, Length[Intersection[#, {centeredVertex}, SameTest -> sameVertex ]] > 0 &];
	Map[getSectionEdge[centeredVertex, #, depth]&, cellFaces]
];


For[shapeIndex = 1, shapeIndex <= Length[shapes], shapeIndex ++,
	shape = shapes[[shapeIndex]];
	dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];
	Print["Reading data for " <> shape <> " from " <> dataFileName];

	outputFileName = "vertex_figure_" <> shape <> ".png";
	imageFolder = "output";
	(* If[exportToPov, outputFileName = "pov_" <> outputFileName ]; *)
	outputFileName = FileNameJoin[{imageFolder, shape, outputFileName}];
	imageSize = {600, 450}; (* has to be 4:3 *)
	(*imageSize = {1000, 750};*)
	cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

	cells = Get[dataFileName];

	Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];

	faces = Union[ Flatten[cells, 1], SameTest -> sameCenter];
	edges = Union[ Flatten[Map[getEdgesFromFace, faces], 1], SameTest -> sameCenter];
	vertices = Union[ Flatten[faces,1], SameTest -> sameVertex];

	Print["There are " <> IntegerString[Length[faces]] <> " faces in total."];
	Print["There are " <> IntegerString[Length[edges]] <> " edges in total."];
	Print["There are " <> IntegerString[Length[vertices]] <> " vertices in total."];

	centeredVertex = vertices[[1]];
	(* Only keep adjacent cells *)
	cells = Select[cells, Length[Intersection[Flatten[#,1], { centeredVertex }, SameTest -> sameVertex ]] > 0 &];
	faces = Union[ Flatten[cells, 1], SameTest -> sameCenter];
	edges = Union[ Flatten[Map[getEdgesFromFace, faces], 1], SameTest -> sameCenter];
	vertices = Union[ Flatten[faces,1], SameTest -> sameVertex];

	Print["Near the vertex, there are " <> IntegerString[Length[cells]] <> " cells."];
	Print["Near the vertex, there are " <> IntegerString[Length[faces]] <> " faces."];
	Print["Near the vertex, there are " <> IntegerString[Length[edges]] <> " edges."];
	Print["Near the vertex, there are " <> IntegerString[Length[vertices]] <> " vertices."];

	selectedEdges = Map[getSectionEdges[centeredVertex, #, cuttingDepth]&, cells];
	selectedEdges = Union[ Flatten[selectedEdges, 1], SameTest -> sameCenter];
	selectedVertices = Union[ Flatten[selectedEdges,1], SameTest -> sameVertex];

	Print["There are " <> IntegerString[Length[cells]] <> " faces in the vertex figure."];
	Print["There are " <> IntegerString[Length[selectedEdges]] <> " edges in the vertex figure."];
	Print["There are " <> IntegerString[Length[selectedVertices]] <> " vertices in the vertex figure."];

	projectionMatrix = getProjectionMatrix[centeredVertex];


	lighting = {{"Point", White, {10, -10, 10}}};

	projectedVertices = Map[projectToDirection[#, projectionMatrix]&, selectedVertices];

	rangeFactor = 1.0;
	range = Norm[projectedVertices[[1]]] * rangeFactor;
	thickness = Norm[projectedVertices[[1]]] * 0.03;

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
				Opacity[1], FaceForm[Green], Map[Cylinder[#, thickness * 2]&, Map[projectToDirection[#, projectionMatrix]&, selectedEdges, {2}]]
			},
			{
				Opacity[1], FaceForm[Green], Map[Sphere[#, thickness * 3]&, Map[projectToDirection[#, projectionMatrix]&, selectedVertices]]
			},
(* 
			{
				Opacity[0.25], FaceForm[color], Map[Polygon, Map[projectToDirection[#, projectionMatrix]&, faces, {2}]]
			},
 *)			{
				Opacity[0.25], FaceForm[White], Map[Cylinder[#, thickness / 2]&, Map[projectToDirection[#, projectionMatrix]&, edges, {2}]]
			},
			{
				Opacity[0.5], FaceForm[White], Map[Sphere[#, thickness]&, Map[projectToDirection[#, projectionMatrix]&, vertices]]
			}
		},
		ViewPoint -> {2, -3, 5}*3,
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
];
