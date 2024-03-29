#!/usr/bin/env wolframscript

(* global config *)

exportToPov = True;
secondLayer = False;
range = If[secondLayer, 1.95, 0.8];


Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];

thickness = If[secondLayer, 0.05, 0.02];
lighting = {{"Point", White, {10, -10, 10}}};
outputFolder = "output/polygon";

p = 5;
q = 1;
phi = GoldenRatio;
(* outer pentagon *)
face1 = Table[
		{Sin[t], -Cos[t], 0}, 
		{t, 0, 2 Pi * q, (2 Pi * q) / p}];

(* inner pentagon *)
face2 = Table[
		{phi^(-2) * Sin[t + Pi*q/p], -phi^(-2) * Cos[t + Pi*q/p], 0}, 
		{t, 0, 2 Pi * q, (2 Pi * q) / p}];

q = 2;
(* inner pentagram *)
face3 = Table[
		{Sin[t], -Cos[t], 0}, 
		{t, 0, 2 Pi * q, (2 Pi * q) / p}];

(* outer pentagram *)
face4 = Table[
		{Sin[t+Pi], -Cos[t+Pi], 0} * phi^2,
		{t, 0, 2 Pi * q, (2 Pi * q) / p}];

q = 1;


(* face = SortBy[face, N[Arg[#[[1]] + I * #[[2]]]]&]; *)
faces = {face1, face2, face3, face4};

(* edges = Union[Flatten[ Map[getEdgesFromFace, faces], 1]]; *)

edges1 = Union[Flatten[ Map[getEdgesFromFace, {face1}], 1]];
edges2 = Union[Flatten[ Map[getEdgesFromFace, {face2}], 1]];
edges3 = Union[Flatten[ Map[getEdgesFromFace, {face3}], 1]];
edges4 = Union[Flatten[ Map[getEdgesFromFace, {face4}], 1]];

vertices = Union[Flatten[faces, 1]];

elements = {
		{
			Opacity[1], FaceForm[Red], Map[Polygon,{face2}]
		},
		{
			FaceForm[Yellow], Map[Cylinder[#, thickness]&, edges1]
		},
		{
			FaceForm[Blue], Map[Cylinder[#, thickness]&, edges3]
		}
 	};

If[secondLayer, AppendTo[elements, {
			FaceForm[Purple], Map[Cylinder[#, thickness*0.9]&, edges4]
		}
]];

graph = Graphics3D[
	elements,
	ViewPoint -> {0, 0, 1},
	PlotRange -> {{-range, range}, {-range, range}, {-range, range}},
	Lighting -> lighting
];


imageSize = {400, 300};
outputFileName = If[secondLayer, "pentagram_inside_outside_2.png", "pentagram_inside_outside.png"];
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
