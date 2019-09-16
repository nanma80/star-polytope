#!/usr/bin/env wolframscript

(* 

magick convert -delay 5 *.png out.gif
magick convert out.gif -coalesce -duplicate 1,-2-1 -quiet -layers OptimizePlus  -loop 0 cycle.gif
python -m SimpleHTTPServer 8000

*)

exportToPov = True;
dataFolder = "data";
imageFolder = "output";
imageSize = {600, 450};

allColors = <|
	"3_3" -> Cyan,
	"5_3" -> Red,
	"3_5" -> Green,
	"52_5" -> Blue,
	"5_52" -> Yellow,
	"52_3" -> Magenta,
	"3_52" -> Orange
|>;


allSchlaefliSymbols = <|
	"Icosahedron" -> "3_5",
	"Dodecahedron" -> "5_3",
	"GreatDodecahedron" -> "5_52",
	"GreatIcosahedron" -> "3_52", 
	"GreatStellatedDodecahedron" -> "52_3", 
	"SmallStellatedDodecahedron" -> "52_5"
|>;

(* shape -> {maxExplosionFactor, frameCount}*)
explosionConfigs = <|
	"Icosahedron" -> {0.8, 30},
	"Dodecahedron" -> {0.8, 30},
	"GreatDodecahedron" -> {0.4, 1},
	"GreatIcosahedron" -> {0.4, 30},
	"GreatStellatedDodecahedron" -> {0.2, 30},
	"SmallStellatedDodecahedron" -> {0.8, 30}
|>;

rangeFactor = 0.8;

Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
sameVertex[point1_, point2_] := point1 == point2;
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * (Norm[First[face]//N]/Norm[Mean[face]//N])^1.5 * explosionFactor)&, face];
explodedCell[cell_, explosionFactor_] := Map[
	(# + Mean[Map[Mean,cell]]*(Norm[First[First[cell]]//N]/Norm[Mean[Map[Mean,cell]]//N])^1.0 * explosionFactor)&, 
	cell, {2}];

exportImage[shape_, explosionFactor_, serialNumber_] := Module[
	{outputFileName, vertices, edges, faces, originalFacesCoordinates, facesCoordinates, edgesCoordinates, thickness, lighting, graph},

	outputFolder = shape <> "_edge_images";
	outputFolder = FileNameJoin[{imageFolder, outputFolder}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];

	outputFileName = "animation_" <> shape <> "_" <> IntegerString[serialNumber, 10, 4] <> ".png";
	If[exportToPov, outputFileName = "pov_" <> outputFileName ];
	outputFileName = FileNameJoin[{outputFolder, outputFileName}];

	cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

	faces = PolyhedronData[shape, "Polygons"];
	originalFacesCoordinates = Map[PolygonCoordinates, faces];
	edgesCoordinates = Map[getEdgesFromFace, originalFacesCoordinates];
	edges = Flatten[edgesCoordinates,1];

	viewPoint = If[shape == "SmallStellatedDodecahedron", {2.5, -3, -1}*30, {2.5, -3, 1}*30];

	sortByViewPoint[point_] := N[point.viewPoint];
	sortEdgeByViewPoint[edge_] := N[Total[edge].viewPoint];

	closestEdge = SortBy[edges, sortEdgeByViewPoint][[Length[edges]]];
	closestFaces = Select[originalFacesCoordinates, Length[Intersection[#, closestEdge, SameTest -> sameVertex ]] > 1 &];

	facesCoordinates = Map[explodedFace[#, explosionFactor]&, closestFaces];
	edgesCoordinates = Map[getEdgesFromFace, facesCoordinates];
	vertices = Flatten[facesCoordinates,1];
	edges = Flatten[edgesCoordinates,1];

	thickness = Norm[originalFacesCoordinates[[1]][[1]]] * 0.03;
	lighting = {{"Point", White, {10, -10, 10}}};
	color = allColors[ allSchlaefliSymbols[shape]];

	range = Max[originalFacesCoordinates] * rangeFactor;
	viewCenter = Total[closestEdge]/2;
	viewPoint = viewCenter * 30;

	graph = Graphics3D[
		{
			{
				Opacity[0.5], FaceForm[color], Map[Polygon, facesCoordinates]
			},
			{
				FaceForm[White], Map[Cylinder[#, thickness]&, edges]
			},
			{
				FaceForm[White], Map[Sphere[#, thickness * 2]&, vertices]
			}
		},
		ViewPoint -> viewPoint,
		ViewVertical -> Total[closestFaces[[1]]],
		PlotRange -> {{viewCenter[[1]]-range, viewCenter[[1]]+range}, {viewCenter[[2]]-range, viewCenter[[2]]+range}, {viewCenter[[3]]-range, viewCenter[[3]]+range}},
		Lighting -> lighting
	];


	If[exportToPov,
		If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
		POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize, RenderOptions -> "+A0.001 -J +UA"];
		Run[cropCommand];
		,
		Export[outputFileName, graph];
	];
	Print["Saved the image to " <> outputFileName];
]

exportAnimation[shape_] := Module[
	{
		outputFolder,
		gifFileName,
		gifFolder,
		explosionConfig,
		maxExplosionFactor,
		frameCount,
		explodeStep,
		explosionFactors,
		frameIndex,
		explosionFactor,
		gifCommand
	},

	outputFolder = shape <> "_edge_images";
	outputFolder = FileNameJoin[{imageFolder, outputFolder}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];

	gifFileName = "edge_exploded_" <> shape;
	gifFolder = FileNameJoin[{imageFolder, shape}];
	If[!DirectoryQ[gifFolder], CreateDirectory[gifFolder]];

	explosionConfig = explosionConfigs[shape];
	maxExplosionFactor = explosionConfig[[1]];
	frameCount = explosionConfig[[2]];
	explodeStep = maxExplosionFactor/frameCount;

	epsilon = 0.001;
	explosionFactors = Join[Table[epsilon, {k, Floor[frameCount / 6]}], Table[k, {k, epsilon, maxExplosionFactor + epsilon, explodeStep}]];
	For[ frameIndex = 1, frameIndex <= Length[explosionFactors] , frameIndex++,
		Print["Frame #" <> IntegerString[frameIndex] <> "/" <> IntegerString[Length[explosionFactors]]];
		explosionFactor = explosionFactors[[frameIndex]];
		exportImage[shape, explosionFactor, frameIndex];
	];

	gifCommand = "magick convert -duplicate 1,-2-1 -quiet +repage -alpha remove -loop 0 -delay " <> IntegerString[Floor[150/frameCount]] <> " -dispose 2 " <> outputFolder <> "\\*animation*.png " <> gifFolder <> "\\" <> gifFileName <> ".gif";

	Print[gifCommand];
	Run[gifCommand];
	Print["Saved the animation to " <> gifFolder <> "\\" <> gifFileName <> ".gif"];
]



(*
PolyhedronData["Platonic"]
{Tetrahedron, Cube, Octahedron, Dodecahedron, Icosahedron}

PolyhedronData["KeplerPoinsot"]
{GreatDodecahedron, GreatIcosahedron, GreatStellatedDodecahedron, SmallStellatedDodecahedron}
*)

shapes = {
	(* "Icosahedron",  *)
	(* "Dodecahedron",  *)
	(* "GreatDodecahedron" *)
	(* "GreatIcosahedron"  *)
	(* "GreatStellatedDodecahedron", *)
	"SmallStellatedDodecahedron"
};

Map[exportAnimation, shapes];



