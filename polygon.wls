#!/usr/bin/env wolframscript

(* global config *)

exportToPov = True;
range = 0.8;

Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];

shapes = {
	{5, 1},
	{5, 2},
	{7, 1},
	{7, 2},
	{7, 3},
	{6, 2},
	{17, 6}
};

allColors = <|
	1 -> Red,
	2 -> Blue,
	3 -> Green,
	6 -> Magenta
|>;


thickness = 0.02;
lighting = {{"Point", White, {10, -10, 10}}};
outputFolder = "output/polygon";

For[shapeIndex = 1, shapeIndex <= Length[shapes], shapeIndex++,
	shape = shapes[[shapeIndex]];
	p = shape[[1]];
	q = shape[[2]];

	faces = {Table[{Sin[t], -Cos[t], 0}, {t, 0, 2 Pi * q, (2 Pi * q) / p}]};
	If[p == 6 && q == 2,
		faces = {
			Table[{Sin[t], -Cos[t], 0}, {t, 0, 2 Pi * q, (2 Pi * q) / p}],
			Table[{-Sin[t], Cos[t], 0}, {t, 0, 2 Pi * q, (2 Pi * q) / p}]
		};
	];

	edges = Union[Flatten[ Map[getEdgesFromFace, faces], 1]];
	vertices = Union[Flatten[faces, 1]];
	color = allColors[q];


	graph = Graphics3D[
		{
			{
				Opacity[1], FaceForm[Lighter[color]], Map[Polygon,faces]
			},
			{
				FaceForm[White], Map[Cylinder[#, thickness]&, edges]
			},
			{
				FaceForm[White], Map[Sphere[#, thickness * 3]&, vertices]
			}
		},
		ViewPoint -> {0, 0, 1},
		PlotRange -> {{-range, range}, {-range, range}, {-range, range}},
		Lighting -> lighting
	];


	imageSize = {400, 300};

	outputFileName = "polygon_" <> IntegerString[p] <> "_" <> IntegerString[q] <> ".png";
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];
	outputFileName = FileNameJoin[{outputFolder, outputFileName}];

	cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

	If[exportToPov,
		If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
		POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize, RenderOptions -> "+A0.001 -J +UA"];
		Run[cropCommand];
		,
		Export[outputFileName, graph];
	];
	Print["Saved the image to " <> outputFileName];
]



