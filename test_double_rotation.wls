#!/usr/bin/env wolframscript

shapes = {
	"test",
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

shapes = {
	(* "polytope_3_4_3" *)
	"polytope_5_3_3_cell120"
};

exportToPov = True;
dataFolder = "data";
imageFolder = "output";

imageSizes = <|
	(* "allLayers" -> {1000, 750}, (* must be 4:3 *) *)
	"allLayers" -> 240 * {4, 3}, (* must be 4:3 *)
	"singleLayer" -> 150 * {4, 3} (* must be 4:3 *)
|>;

allColors = <|
	"3_3" -> Cyan,
	"5_3" -> Red,
	"3_5" -> Green,
	"52_5" -> Blue,
	"5_52" -> Yellow,
	"52_3" -> Magenta,
	"3_52" -> Orange,
	"3_4" -> Green
|>;

(* shape -> {maxExplosionFactor, frameCount}*)
explosionConfigs = <|
	"polytope_3_4_3" -> {3.0, 150},
	(* 120-cell *)
	"polytope_5_3_3_cell120" -> {1.3, 100},

	(* 600-cell *)
	"polytope_3_3_5_cell600" -> {3.0, 150},

	(* Icosahedral 120-cell. cell: icosahedron *)
	"polytope_3_5_52" -> {2.0, 30},

	(* Small stellated 120-cell. cell: {5/2, 5}. Small stellated dodecahedron *)
	"polytope_52_5_3" -> {2.0, 30},

	(* Great 120-cell. cell: {5, 5/2}. Great dodecahedron. Self dual *)
	"polytope_5_52_5" -> {2.0, 30},

	(* Grand 120-cell. cell: {5, 3}. Dodecahedron *)
	"polytope_5_3_52" -> {2.0, 30},

	(* Great stellated 120-cell. cell: great stellated dodecahedron *)
	"polytope_52_3_5" -> {2.0, 30},

	(* Grand stellated 120-cell. cell: {5/2, 5}. Small stellated dodecahedron. Self dual *)
	"polytope_52_5_52" -> {2.0, 30},

	(* Great grand 120-cell. cell: Great dodecahedron *)
	"polytope_5_52_3" -> {2.0, 30},

	(* Greate icosahedral 120-cell. cell: great icosahedron *)
	"polytope_3_52_5" -> {2.0, 30},

	(* Grand 600-cell. cell: tetrahedron, 600 cells *)
	"polytope_3_3_52" -> {2.0, 30},

	(* Great grand stellated 120-cell. cell: great stellated dodecahedron *)
	"polytope_52_3_3" -> {2.0, 30},

	"test" -> {2.0, 3}
|>

rangeFactor = 3.0;
originalProjectionMatrixH4 = {
    {0.00, 0, 2 Sin[2 Pi/15], (1 + Sqrt[5]) Sin[Pi/15]},
    {1, -(1 + Sqrt[5]) Sin[Pi/30], 0, 0.00},
    {1, 3, 4, 1},
    {0, 0, 0, 1}
} * 1.0;

originalProjectionMatrixF4 = {
	{1, 1, Sqrt[3] - 1, 0},
	{1, -1, 0, Sqrt[3] - 1},
    {1, 3, 4, 1},
    {0, 0, 0, 1}
} * 1.0;

phi = (1 + Sqrt[5])/2;
viewPoint = {1, -1, 1};
(* viewPoint = {0.01, 0.01, 1}; *)
(* viewPoint = {1.0, 0.0, 0.0}; *)
(* matrix3D = {viewPoint, {0, 1, 0}, {0, 0, 1}}; *)
(* perpViewPoints = Orthogonalize[matrix3D][[2;;3]]; *)
(* rotation3D = RotationMatrix[{{0, 0, 1}, viewPoint}]; *)
(* rotation3D = IdentityMatrix[3]; *)
(* projectionMatrix = rotation3D.Orthogonalize[originalProjectionMatrixH4][[1;;3]]; *)
(* projectionMatrix = rotation3D.Orthogonalize[originalProjectionMatrixF4][[1;;3]]; *)
(* projectionMatrix = rotation3D.IdentityMatrix[4][[1;;3]]; *)

Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

(* projectTo3d[vertex4d_] := {vertex4d[[1]], vertex4d[[2]], vertex4d[[3]]}; *)
(* projectTo3d[vertex4d_] := projectionMatrix.vertex4d; *)
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
normalizedAngle[u_, v_] := ArcSin[u.v/Norm[u]/Norm[v]]/Pi + 0.5;
projectToDirection[vertex4d_, projectionMatrix_] := projectionMatrix.vertex4d;
perspectiveProjection[point_, fullProjectionMatrix_, wDistance_ ] := projectToDirection[point, fullProjectionMatrix[[1;;3]]] / (1 + point.(fullProjectionMatrix[[4]])/wDistance);

For[shapeIndex = 1, shapeIndex <= Length[shapes], shapeIndex ++,
	shape = shapes[[shapeIndex]];	
	If[
		StringContainsQ[shape, "polytope_3_3_"],
		activeLayerMin = 1; activeLayerMax = 15,
		(* activeLayerMin = 2; activeLayerMax = 5 *)
		activeLayerMin = 1; activeLayerMax = 5
	];

	(* exportImage[shape, activeLayerMin, activeLayerMax, 1.0, 0]; *)

	(* exportAnimation[shape, activeLayerMin, activeLayerMax]; *)
];

deltaTheta = Pi/240;
(* exportImage[shape, 1, 9, 2.9, 48 deltaTheta, 9]; *)
exportImage[shape, 1, 9, 2.9, 0 deltaTheta, 10];

activeLayerMin = 1;
activeLayerMax = 9;

explosionFactor = 2.9;
serialNumber = 6;

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

thickness = Norm[cells[[1]][[1]][[1]]] * 0.008;
lighting = {{"Point", White, viewPoint * 10}};
range = Norm[cells[[1]][[1]][[1]]] * rangeFactor;

outputFolder = shape <> "_double_rotation";
outputFolder = FileNameJoin[{imageFolder, outputFolder}];
If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];

outputFileName = "animation_" <> shape <> "_layers_" <> IntegerString[activeLayerMin] <> "_" <> IntegerString[activeLayerMax] <> "_" <> IntegerString[serialNumber, 10, 4] <> ".png";
If[exportToPov, outputFileName = "pov_" <> outputFileName ];
outputFileName = FileNameJoin[{outputFolder, outputFileName}];

imageSize = imageSizes[If[activeLayerMin < activeLayerMax, "allLayers", "singleLayer"]];
cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

inactiveCells = Apply[Join, Table[cellsByLayers[layerKeys[[k]]], {k, 1, activeLayerMin - 1}]];
Print["Selected " <> IntegerString[Length[inactiveCells]] <> " inactive cells."];

inactiveFaces = Union[ Flatten[inactiveCells, 1], SameTest -> sameCenter];
inactiveEdges = Union[ Flatten[Map[getEdgesFromFace, inactiveFaces], 1], SameTest -> sameCenter];
inactiveVertices = Union[ Flatten[inactiveFaces,1], SameTest -> sameVertex];

activeCells = Apply[Join, Table[cellsByLayers[layerKeys[[k]]], {k, activeLayerMin, activeLayerMax}]];
Print["Selected " <> IntegerString[Length[activeCells]] <> " active cells. ExplosionFactor: " <> TextString[explosionFactor]];

activeCells = Map[explodedCell[#, explosionFactor]&, activeCells];
activeFaces = Flatten[activeCells, 1];
(* activeEdges = Union[ Flatten[Map[getEdgesFromFace, activeFaces], 1], SameTest -> sameCenter]; *)
(* activeVertices = Union[ Flatten[activeFaces,1], SameTest -> sameVertex]; *)
activeEdges = Flatten[Map[getEdgesFromFace, activeFaces], 1];
activeVertices = Flatten[activeFaces,1];

(* range = range /2; *)
(* projectedActiveFaces = Map[projectTo3d, activeFaces, {2}]; *)
activeCellsCenters = Map[Total[#, 2]/Length[activeCells[[1]]]/Length[activeCells[[1]][[1]]]&, activeCells];
(* activeCellsCenters = Map[projectTo3d, activeCellsCenters]; *)
(* activeCellsCenters = activeCellsCenters/Norm[activeCellsCenters[[1]]]; *)

 wDistance = Max[Flatten[activeFaces]] * 1.2;
 Print[wDistance];
 (* fullProjectionMatrix = IdentityMatrix[4]; *)
 (* rotation3D = RotationMatrix[{{0, 0, 1}, {1, 0, phi}}]; *)
 (* rotation3D = RotationMatrix[{{1, 0, phi}, {0, 0, 1}}]; *)
 rotation3D = RotationMatrix[-ArcTan[1/phi], {0, 1, 0}];
 fullProjectionMatrix = ArrayFlatten[
 	{{rotation3D, 0}, {0, 1}}
];

theta = 0. + Pi/15.;

doubleRotation = ArrayFlatten[{{RotationMatrix[theta], 0}, {0, RotationMatrix[theta]}}];
(* fullProjectionMatrix = fullProjectionMatrix . doubleRotation; *)
fullProjectionMatrix = doubleRotation.fullProjectionMatrix;

(* 	perspectiveProjection[activeCellsCenters[[11]], fullProjectionMatrix, wDistance]
centers = Table[ perspectiveProjection[activeCellsCenters[[k]], fullProjectionMatrix, wDistance], {k, 120}]
Select[centers, Norm[{#[[1]], #[[2]]}] < 0.01&]
*)
 projectedActiveFaces = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, activeFaces, {2}];
 range = Max[Flatten[activeFaces]];

 (* edges3D = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, edgeSegments, {2}]; *)
 (* vertices3D = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, selectedEdgeEnds]; *)
 (* otherVertices3D = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, selectedVertices]; *)

 faceCellRatio = Length[activeFaces]/Length[activeCellsCenters];
 grayArea = 0.1;

rotatedActiveCellsCenters = Map[fullProjectionMatrix.#&, activeCellsCenters];

roundPrecision = 0.000001;
mapHopfFibration[v4d_] := Module[
	{z0, z1},
	z0 = v4d[[1]] + I v4d[[2]];
	z1 = v4d[[3]] + I v4d[[4]];
	x1 = Re[(2 z0 Conjugate[z1])];
	x2 = Im[(2 z0 Conjugate[z1])];
	x3 = Re[z0 Conjugate[z0] - z1 Conjugate[z1]];
	Round[{x1, x2, x3}, roundPrecision]
];


hopf3dCenters = Map[mapHopfFibration, rotatedActiveCellsCenters];
hopf3dCenters//Tally//Sort
(* 
Out[342]= {{{-111.072, 0., -55.5358}, 10}, {{-89.8588, -65.2863, 55.5358}, 10}, {{-89.8588, 65.2863, 55.5358}, 10},

>    {{-34.323, -105.635, -55.5358}, 10}, {{-34.323, 105.635, -55.5358}, 10}, {{0., 0., -124.182}, 10}, {{0., 0., 124.182}, 10},

>    {{34.323, -105.635, 55.5358}, 10}, {{34.323, 105.635, 55.5358}, 10}, {{89.8588, -65.2863, -55.5358}, 10},

>    {{89.8588, 65.2863, -55.5358}, 10}, {{111.072, 0., 55.5358}, 10}}
 *)
distinctCenters3d = hopf3dCenters//Union//Sort;

getHue[v3d_] := If[Norm[v3d[[{1, 2}]]] < 0.001, 
						If[v3d[[3]] > 0, Red, Blue],
						Hue[Mod[Arg[v3d[[1]] + I v3d[[2]]] , 1]]
	0 ];
Map[getHue, distinctCenters3d]

Select[rotatedActiveCellsCenters, Norm[#[[{1,2}]]] < 0.001&]
(* only 4?? should be ten *)

graph = Graphics3D[
	{
		Table[{
				(* Opacity[1.0], *)
				Opacity[
					If[
					activeCellsCenters[[Floor[(k - 1)/faceCellRatio] + 1]].(activeCellsCenters[[Floor[(k - 1)/faceCellRatio] + 1]] + {0, 0, 0, wDistance}) < 0, 0, 1]
				],
				FaceForm[Blue],
				(* FaceForm[ Hue[ normalizedAngle[activeCellsCenters[[Floor[(k - 1)/12] + 1]], {1, -1, 1} ] ]],  *)
				(* FaceForm[ Hue[ Arg[activeCellsCenters[[Floor[(k - 1)/8] + 1]].perpViewPoints[[1]] + I activeCellsCenters[[Floor[(k - 1)/8] + 1]].perpViewPoints[[2]]] / 2 / Pi + 0.5 ]], *)
				Polygon[ projectedActiveFaces[[k]] ]
			}, {k, 1, Length[activeFaces]}
		]

(* 			{
			FaceForm[White], Map[Cylinder[#, thickness]&, Map[projectTo3d, activeEdges, {2}]]
		},
		{
			FaceForm[White], Map[Sphere[#, thickness * 2]&, Map[projectTo3d, activeVertices]]
		}
*)
	},

	ViewPoint -> viewPoint * 100,
	ViewVertical -> {0, 0, 1},
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
