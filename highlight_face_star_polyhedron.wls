#!/usr/bin/env wolframscript

exportToPov = True;
specialViewPoint = False;

Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

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

sameVertex[point1_, point2_] := point1 == point2;
getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
getSectionVertices[edges_, vertex_, depth_] := Module[
	{closestEdges},
	sortByViewPoint[point_] := N[point.vertex];
	closestEdges = Select[edges, (#[[1]] == vertex || #[[2]] == vertex)&];
	closestEdges = Map[SortBy[#, sortByViewPoint]&, closestEdges];
	Map[depth * #[[1]] + (1 - depth) * #[[2]]& , closestEdges]
];
getFaceCenter[face_] := Simplify[Total[PolygonCoordinates[face]]/5];

exportPolyhedron[shape_] := Module[
	{outputFileName, imageSize, vertices, edges, faces, thickness, lighting, graph},

	outputFileName = "highlight_face_" <> shape <> ".png";
	imageFolder = "output";
	outputFolder = FileNameJoin[{imageFolder, shape}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];
	If[specialViewPoint, outputFileName = "north_pole_" <> outputFileName ];
	If[exportToPov, outputFileName = "pov_" <> outputFileName ];
	outputFileName = FileNameJoin[{outputFolder, outputFileName}];
	imageSize = {600, 450}; (* has to be 4:3 *)
	cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

	vertices = PolyhedronData[shape, "Vertices"];
	edges = PolyhedronData[shape, "EdgeCoordinates"];
	faces = PolyhedronData[shape, "Polygons"];
	thickness = Norm[vertices[[1]]] * 0.015;
	lighting = {{"Point", White, {10, -10, 10}}};
	range = 0.8 * Norm[vertices[[1]]];
	color = allColors[ allSchlaefliSymbols[shape]];
	viewPoint = If[specialViewPoint, 
		If[shape == "SmallStellatedDodecahedron", -vertices[[1]]*10, {0, 0, 1}*10], 
		{3, -3, 5}*3
	];

	sortByViewPoint[face_] := N[getFaceCenter[face].viewPoint];
	closestFace = SortBy[faces, sortByViewPoint][[Length[faces]]];
	otherFaces = Complement[faces, {closestFace}];
	Print[Length[otherFaces]];
	viewCenter = {0, 0, 0};
	viewPoint = getFaceCenter[closestFace] * 50;

	graph = Graphics3D[
		{
			{
				Opacity[0.5], FaceForm[color], otherFaces
			},
			{
				FaceForm[Lighter[Gray]], {closestFace}
			},
			{
				FaceForm[White], Map[Cylinder[#, thickness]&, edges]
			},
			{
				FaceForm[White], Map[Sphere[#, thickness * 2]&, vertices]
			}
		},
		ViewPoint -> viewPoint,
		PlotRange -> {{viewCenter[[1]]-range, viewCenter[[1]]+range}, {viewCenter[[2]]-range, viewCenter[[2]]+range}, {viewCenter[[3]]-range, viewCenter[[3]]+range}},
		Lighting -> lighting
	];


	If[exportToPov,
		If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
		POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize, RenderOptions -> "+A0.001 -J +UA"];
		Run[cropCommand];
		,
		Export[outputFileName, graph]
	];
]

shapes = {
	(* "Icosahedron", *)
	(* "Dodecahedron", *)
	"GreatDodecahedron", 
	"GreatIcosahedron", 
	"GreatStellatedDodecahedron", 
	"SmallStellatedDodecahedron"
};

Map[exportPolyhedron, shapes];

