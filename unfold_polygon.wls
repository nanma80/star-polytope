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
epsilon = 0.00000001;
ApproxSamePoint[point1_, point2_] := Round[point1, epsilon] == Round[point2, epsilon];
allColors = {Red, Blue, Green, Yellow, Purple};

exportImage[p_, q_, unfoldPercents_, serialNumber_] := Module[
	{},

	edges = foldFaces[originalEdges, rotationSchedule, unfoldPercents];
	(* Print[edges]; *)

	vertices = Union[Flatten[edges, 1]];
	color = If[p == 5, Blue, Green];
	radius = Max[Norm/@vertices];
	range = radius * 0.8;
	(* Print[range]; *)

	graph = Graphics3D[
		{
			Table[
				{
					FaceForm[ allColors[[k]] ], Cylinder[edges[[k]], thickness]
				}, {k, 1, Length[edges]}
			],
			{
				FaceForm[White], Map[Sphere[#, thickness * 3]&, vertices]
			}
		},
		ViewPoint -> {0, 0, 1} * 100,
		PlotRange -> {{-range, range}, {-range, range}, {-range, range}},
		Lighting -> lighting
	];

	imageSize = {4, 3} * 720/3;

	outputFileName = "unfold_polygon_animation_" <> IntegerString[p] <> "_" <> IntegerString[q] <> "_" <> IntegerString[serialNumber, 10, 4] <> ".png";
	outputFolder = "output/unfold_polygon_animation_images_" <> IntegerString[p] <> "_" <> IntegerString[q];

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

smoothFall[x_, start_, duration_] := If[x < start, 1, If[x > start + duration, 0, (1 + Cos[(x - start)/duration*Pi])/2]];
smoothFallFromTo[x_, start_, duration_, from_, to_] := smoothFall[x, start, duration] (from - to) + to;

exportAnimation[p_, q_, frameCount_] := Module[{},

	unfoldPercents = Table[smoothFall[x, 0, 1]//N, {x, 0, 1, 1/(frameCount-1)}, {k, maxLevel}];

	negativePercents = Table[smoothFallFromTo[x, 0, 1, 0, -1]//N, {x, 0, 1, 1/(frameCount - 1)}, {k, maxLevel}];

	zeros = Table[0.0, {x, 0, 1, 1/(Round[frameCount/3] - 1)}, {k, maxLevel}];

	minusOnes = Table[-1.0, {x, 0, 1, 1/(Round[frameCount/4] - 1)}, {k, maxLevel}];

	unfoldPercents = Join[unfoldPercents, zeros, negativePercents, minusOnes ];

	For[ frameIndex = 1, frameIndex <= Length[unfoldPercents] , frameIndex++,
		(* Continue[]; *)
		(* If[frameIndex < 90, Continue[]]; *)
		unfoldPercent = unfoldPercents[[frameIndex]];
		Print["Frame #" <> IntegerString[frameIndex] <> "/" <> IntegerString[Length[unfoldPercents]]];
		
		exportImage[p, q, unfoldPercent, frameIndex];
	];

	delay = 3;
	outputFolder = "output/unfold_polygon_animation_images_" <> IntegerString[p] <> "_" <> IntegerString[q];
	gifFileName = "unfold_polygon_" <> IntegerString[p] <> "_" <> IntegerString[q];
	gifCommand = "magick convert -duplicate 1,-2-1 -quiet +repage -alpha remove -loop 0 -delay " <> IntegerString[delay] <> " -dispose 2 " <> outputFolder <> "\\unfold_polygon_animation_" <> IntegerString[p] <> "_" <> IntegerString[q] <> "*.png " <> gifFolder <> "\\" <> gifFileName <> ".gif";

	Print[gifCommand];
	Run[gifCommand];
	Print["Saved the animation to " <> gifFolder <> "\\" <> gifFileName <> ".gif"];
	
	mp4Command = "ffmpeg -i " <> gifFolder <> "\\" <> gifFileName <> ".gif" 
	  <> " -movflags faststart -pix_fmt yuv420p -vf \"scale=trunc(iw/2)*2:trunc(ih/2)*2\" "
	  <> gifFolder <> "\\" <> gifFileName <> ".mp4";

	mp4FileName = gifFolder <> "\\" <> gifFileName <> ".mp4";
	If[FileExistsQ[mp4FileName], DeleteFile[mp4FileName]];
	Print[mp4Command];
	Run[mp4Command];
	Print["Saved the video to " <> gifFolder <> "\\" <> gifFileName <> ".mp4"];
];

buildSchedule[t_, schedule_, level_] := Module[
	{subtrees, subtreeId, newSchedule},
	newSchedule = schedule;
	subtrees = TreeChildren[t];
	For[subtreeId = 1, subtreeId <= Length[subtrees], subtreeId++,
		subtree = subtrees[[subtreeId]];
		subtreeAllData = Map[#[[1]] &, VertexList[TreeGraph[subtree]]];
		newSchedule = Append[newSchedule, {TreeData[t], TreeData[subtree], level, subtreeAllData}];
		newSchedule = buildSchedule[subtree, newSchedule, level + 1];
	];
	newSchedule
];

foldFaces[faces_, rotationSchedule_, foldPercents_] := Module[
	{originalDihedralAngle, rotatedFaces, scheduleId, level, schedule, face1Id, face2Id, rotatedFaceIds},
	originalDihedralAngle = 0;
	rotatedFaces = faces;

	For[scheduleId = 1, scheduleId <= Length[rotationSchedule], scheduleId++,
		schedule = rotationSchedule[[scheduleId]];
		level = schedule[[3]];
		If[level >= 1,
			(* Print[schedule]; *)
			face1Id = schedule[[1]];
			face2Id = schedule[[2]];
			rotatedFaceIds = schedule[[4]];
			face1 = rotatedFaces[[face1Id]];
			face2 = rotatedFaces[[face2Id]];
			pivot = Intersection[face1, face2, SameTest -> ApproxSamePoint];
			If[Length[pivot] != 1,
				Print["Unexpected error. Cannot find correct pivot"];
				Print[schedule];
				Print[pivot];
				Exit[];
			];

			faceCenter1 = Mean[face1];
			faceCenter2 = Mean[face2];
			pivotCenter = Mean[pivot];
			relativeFace1 = faceCenter1 - pivotCenter;
			relativeFace2 = faceCenter2 - pivotCenter;

			originalDihedralAngle = ArcCos[ Dot[relativeFace1, relativeFace2]/Norm[relativeFace1]/Norm[relativeFace2] ];
			(* Print[originalDihedralAngle / Pi * 180]; *)
			angleToFlat = Pi - originalDihedralAngle;
			angleToStellate = 36/180.0 * Pi - originalDihedralAngle;

			perc = foldPercents[[level]];
			angleToTarget = If[perc >= 0, angleToFlat, angleToStellate];

			rotMatrix = RotationMatrix[angleToTarget * Abs[perc], {relativeFace2, relativeFace1}];
			(* Print[rotMatrix]; *)

			(* Print[{ scheduleId, ApproxSamePoint[relativeFace2.rotMatrix + relativeFace1, {0, 0, 0}] }]; *)
			For[fid = 1, fid <= Length[rotatedFaceIds], fid++,
				faceId = rotatedFaceIds[[fid]];
				(* Print["rotating face " <> IntegerString[faceId]]; *)
				rotatedFace = rotatedFaces[[faceId]];
				rotatedFace = Map[((# - pivotCenter).rotMatrix + pivotCenter)&, rotatedFace];
				rotatedFaces[[faceId]] = rotatedFace;
			];
		];
	];

	rotatedFaces
];


(* two edges meeting on the y-axis is treated as if they are not adjacent. This is forcing a symmetric graph at the end *)
adjacentFaces[f1_,f2_] := Length[Intersection[f1, f2, SameTest -> ApproxSamePoint]] == 1 && Abs[Intersection[f1, f2, SameTest -> ApproxSamePoint][[1]][[1]]] > epsilon ;
adjacentFacesIndex[faces_, id1_, id2_] := adjacentFaces[faces[[id1]], faces[[id2]]];

p = 5;
q = 1;
faces = {Table[{Sin[t], -Cos[t], 0}, {t, 0, 2 Pi * q - (2 Pi * q) / p, (2 Pi * q) / p}]};
originalEdges = Union[Flatten[ Map[getEdgesFromFace, faces], 1]];
edgeCenters = Mean/@originalEdges;
rootEdgeId = Select[Range[Length[edgeCenters]], Abs[edgeCenters[[#]][[1]]] < epsilon & ][[1]];

adjMatrix = Table[If[adjacentFacesIndex[originalEdges, id1, id2], 1, 0], {id1, 1, Length[originalEdges]}, {id2, 1, Length[originalEdges]}];
Print[adjMatrix];

graph = AdjacencyGraph[Range[Length[adjMatrix]], adjMatrix ];

(* Print[EdgeList[graph]];
Exit[];
edgeSubsets = Subsets[EdgeList[graph], {Length[EdgeList[graph]] - 5} ];
Print[Length[edgeSubsets]];

subsetId = RandomInteger[{1, Length[edgeSubsets]}];
Print["subsetId"];
Print[subsetId];
spanningTree = FindSpanningTree[DirectedGraph[Graph[edgeSubsets[[subsetId]]]]];
 *)

spanningTree = FindSpanningTree[DirectedGraph[graph]];
tree = GraphTree[spanningTree, rootEdgeId ];

rotationSchedule = {};

rotationSchedule = buildSchedule[tree, rotationSchedule, 1];
Print[rotationSchedule];

maxLevel = Max[Map[#[[3]]&, rotationSchedule ]];
Print[maxLevel];

(* foldPercents = Table[-1.0, {k, maxLevel}]; *)

(* exportAnimation[p, q, 10]; *)
exportAnimation[p, q, 150];

(* exportAnimation[7, 3, 30]; *)
(* exportAnimation[9, 4, 3]; *)

(* exportImage[p, q, foldPercents, 1]; *)

(* exportImage[7, 3, Tan[3 Pi/7]/Tan[Pi/7]-1, 1]; *)