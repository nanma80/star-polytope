#!/usr/bin/env wolframscript

(* global config *)

exportToPov = True;

Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
explodedEdge[edge_, explosionFactor_] := Map[(# + Mean[edge] * explosionFactor)&, edge];

thickness = 0.03;
lighting = {{"Point", White, {10, -10, 10}}};
gifFolder = "output/polygon";
phi = GoldenRatio;

exportImage[p_, q_, explosionFactor_, serialNumber_] := Module[
	{},

	faces = {Table[{Sin[t], -Cos[t], 0}, {t, 0, 2 Pi * q - (2 Pi * q) / p, (2 Pi * q) / p}]};
	originalEdges = Union[Flatten[ Map[getEdgesFromFace, faces], 1]];
	edges = Map[explodedEdge[#, explosionFactor]&, originalEdges];
	vertices = Union[Flatten[edges, 1]];
	color = If[p == 5, Blue, Green];
	radius = Sin[q Pi/p]/Sin[Pi/p];
	range = radius * 0.8;
	Print[range];

	graph = Graphics3D[
		{
			{
				FaceForm[Lighter[color, 0.4]], Map[Cylinder[#, thickness]&, edges]
			},
			{
				FaceForm[color], Map[Sphere[#, thickness * 3]&, vertices]
			}
		},
		ViewPoint -> {0, 0, 1},
		PlotRange -> {{-range, range}, {-range, range}, {-range, range}},
		Lighting -> lighting
	];

	imageSize = {400, 300};

	outputFileName = "polygon_animation_" <> IntegerString[p] <> "_" <> IntegerString[q] <> "_" <> IntegerString[serialNumber, 10, 4] <> ".png";
	outputFolder = "output/polygon_animation_images_" <> IntegerString[p] <> "_" <> IntegerString[q];

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
];

exportAnimation[p_, q_, frameCount_] := Module[{},
	maxExplosionFactor = Tan[q Pi/p]/Tan[Pi/p]-1;
	explodeStep = maxExplosionFactor/frameCount;

	explosionFactors = Join[Table[0, {k, Floor[frameCount / 6]}], 
		Table[k, {k, 0, maxExplosionFactor, explodeStep}],
		Table[maxExplosionFactor, {k, Floor[frameCount / 6]}]
		];

	For[ frameIndex = 1, frameIndex <= Length[explosionFactors] , frameIndex++,
		Print["Frame #" <> IntegerString[frameIndex] <> "/" <> IntegerString[Length[explosionFactors]]];
		explosionFactor = explosionFactors[[frameIndex]];
		exportImage[p, q, explosionFactor, frameIndex];
	];

	outputFolder = "output/polygon_animation_images_" <> IntegerString[p] <> "_" <> IntegerString[q];
	gifFileName = "exploded_" <> IntegerString[p] <> "_" <> IntegerString[q];
	gifCommand = "magick convert -duplicate 1,-2-1 -quiet +repage -alpha remove -loop 0 -delay " <> IntegerString[Floor[150/frameCount]] <> " -dispose 2 " <> outputFolder <> "\\polygon_animation_" <> IntegerString[p] <> "_" <> IntegerString[q] <> "*.png " <> gifFolder <> "\\" <> gifFileName <> ".gif";

	Print[gifCommand];
	Run[gifCommand];
	Print["Saved the animation to " <> gifFolder <> "\\" <> gifFileName <> ".gif"];
];

exportAnimation[5, 2, 30];
exportAnimation[7, 3, 30];
(* exportAnimation[9, 4, 3]; *)
(* exportImage[5, 2, 2 phi, 1]; *)
(* exportImage[7, 3, Tan[3 Pi/7]/Tan[Pi/7]-1, 1]; *)