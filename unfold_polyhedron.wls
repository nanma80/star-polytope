#!/usr/bin/env wolframscript

exportToPov = True;
highlightCenter = False;

topView = True;
topView = False;

showEdges = True;
(* showEdges = False; *)

stellateAllFaces = True;
(* stellateAllFaces = False; *)

stereographicProjection = True;
stereographicProjection = False;

(* projectionRatio = 0.003; *)

(* projectionRatio = 0: touches the sphere. = 1: projected to a plane *)
projectionRatio = .01;
(* projectionRatio = 0.12; *)
maxProjectionRatio = 0.1;

(* stellationLevel = 0, no stellation. Original spherical polygon. = 1: full stellation *)
stellationLevel = 1;

imageSize = {4, 3} * 720 / 3;
lightSource = {50,-50,50};
lighting = {{"Point", White, lightSource}};

(* frameCount = 10; *)
frameCount = 300;

argv = Rest @ $ScriptCommandLine;
If[Length[argv] >= 2, 
	p = ToExpression[argv[[1]]]; q = ToExpression[argv[[2]]],
	p = 5; q = 3; (* default *)
];

If[Length[argv] >= 3, 
	r = ToExpression[argv[[3]]],
	r = 1; (* default *)
];

splitEdgeParts = 2;

colorGroup = {Red, Blue, Green, Yellow, Magenta, Cyan, Brown, Orange};
colors = Join[colorGroup, Map[Darker[#, 0.5]&, colorGroup], Map[Lighter[#, 0.5]&, colorGroup]];

maxStellationLevel = If[Length[argv] >= 3, ToExpression[argv[[3]]], 1];
maxRatio = Tan[maxStellationLevel Pi/p]/Tan[Pi/p];
nGenerations = If[Length[argv] >= 4, ToExpression[argv[[4]]], 4];
dihedralSpherical = 0;
dihedralHyperbolic = 0;

shape = "unfold_polyhedron_" <> ToString[p, InputForm] <> "_" <> ToString[q, InputForm] <> "_" <> ToString[r, InputForm];


norm = 1.0;
imageFolder = "output";

Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

HInner[v_, u_, sig_] := If[sig > 0, 2 * v[[1]] * u[[1]] - Dot[v, u], Dot[v, u]];
HNormSquare[v_, sig_] := HInner[v, v, sig];
HNorm[v_, sig_] := Sqrt[HNormSquare[v, sig]];
rotated[vertices_, center_, axis_, angle_] := Map[# + center &, Map[# - center &, vertices].RotationMatrix[angle, axis]];
Rotation[t_] :=
{
  {1,  0, 0},
  {0, Cos[t], Sin[t]},
  {0, -Sin[t], Cos[t]}
};
epsilon = 0.00000001;
HReflect[point_, mirror_, sig_] := If[sig!= 0, 
	point - 2 * HInner[point, mirror, sig]/HInner[mirror, mirror, sig]*mirror,
	point - 2 * (mirror[[2]]*point[[2]] + mirror[[3]]*point[[3]] + mirror[[1]])/(mirror[[2]]^2 + mirror[[3]]^2) * {0, mirror[[2]], mirror[[3]]}
	];
HDoubleReflect[point_, mirror1_, mirror2_, sig_] := HReflect[HReflect[point, mirror1, sig], mirror2, sig];
(* ApproxSamePoint[point1_, point2_] := Norm[N[point1 - point2]] < 0.00001; *)
ApproxSamePoint[point1_, point2_] := Round[point1, epsilon] == Round[point2, epsilon];

getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
sameCenter[set1_, set2_] := ApproxSamePoint[Total[set1], Total[set2]];
(* sameEdge[e1_, e2_] := sameCenter[e1, e2] && ((ApproxSamePoint[e1[[1]], e2[[1]]] && ApproxSamePoint[e1[[2]], e2[[2]]] ) || (ApproxSamePoint[e1[[1]], e2[[2]]] && ApproxSamePoint[e1[[2]], e2[[1]]] )); *)
sameEdge[e1_, e2_] := sameCenter[e1, e2];

getKlein[v_] := {0, v[[2]], v[[3]]}/v[[1]];
getPoincare[v_] := {0, v[[2]], v[[3]]}/(1+v[[1]]);
splitEdge[edge_, n_] := Table[{k edge[[1]] + (1-k) edge[[2]], (k+1/n) edge[[1]] + (1-k-1/n) edge[[2]] }, {k, 0, 1 - 1/n, 1/n}];
HNormalize[v_, norm_] := v/HNorm[v] * norm;
getHyperboloid[v_] := {v[[1]], v[[2]], v[[3]]};
normalize[v_, norm_] := v/Norm[v] * norm;
scale[edge_, ratio_] := Module[
	{center},
	center = Mean[edge];
	Map[(# - center) * ratio + center&, edge]
];

trimFaces[faces_] := Module[
	{},
	allEdges = Flatten[Map[getEdgesFromFace, faces], 1];
	allEdgesTally = Tally[allEdges, ApproxSamePoint[Total[#1], Total[#2]]&];
	commonEdges = Map[#[[1]]&, Select[allEdgesTally, #[[2]] > 1 &]];
	trimmedFaces = Select[faces, Length[Intersection[getEdgesFromFace[#], commonEdges, SameTest -> sameCenter]] > 1 & ];
	trimmedFaces
];

splitFaceToTriangles[face_, faceCenter_] := Module[
	{},
	output = {};
	normalizedFaceCenter = faceCenter/Norm[faceCenter] * Norm[face[[1]][[1]] ];
	edges = face;
	For[eid = 1, eid <= Length[edges], eid++,
		edge = edges[[eid]];
		AppendTo[output, {normalizedFaceCenter, edge[[1]], edge[[2]] }];
	];
	
	output
];

scaleFace[face_, ratio_, stellationLevel_] := Module[
	{edges, edgeOrders},
	edges = Map[scale[#, ratio]&, getEdgesFromFace[face]];
	edgeOrders = Table[Mod[stellationLevel * k, p]+1, {k, 0, p-1}];
	(* edges[[edgeOrders]] *)
	(* Map[#[[1]]&, edges[[edgeOrders]]] *)
	Flatten[edges[[edgeOrders]], 1]
];

boost[t_] :=
{
  {Cosh[t], 0, Sinh[t]},
  {0, 1, 0},
  {Sinh[t], 0, Cosh[t]}
};

(* only works if axis[[1]] == 0 *)
boostMatrix[angle_, axis_] := RotationMatrix[Arg[axis[[2]] + I axis[[3]]], {1, 0, 0}].boost[angle].RotationMatrix[-Arg[axis[[2]] + I axis[[3]]], {1, 0, 0}];

boosted[vertices_, center_, axis_, angle_] := Map[# + center &, Map[# - center &, vertices].boostMatrix[angle, axis]];

(* line between a point on sphere and the stereographic projection on a plane *)
(* partialProjection[p_, center_, norm_, projectionRatio_] := (p - center)/Norm[(p - center)] * (Norm[(p - center)] (1 - projectionRatio) + projectionRatio * (4*norm*norm/Norm[(p - center)] ) )  + center; *)

(* scale out the point away from origin *)
partialProjection[p_, center_, norm_, projectionRatio_] := If[stereographicProjection,
(p - center)/Norm[(p - center)] * (Norm[(p - center)] (1 - projectionRatio) + projectionRatio * (4*norm*norm/Norm[(p - center)] ) )  + center,
ArcCos[Dot[p, -center]/Norm[p]/Norm[center]]/Pi*projectionRatio * p + p];

shapeWithParams = shape <> If[topView, "_top", ""] <> If[showEdges, "_show_edges", ""] <> If[stellateAllFaces, "_all_star", ""] <> If[stereographicProjection, "_stereo", ""] <> "_" <> IntegerString[ Round[projectionRatio * 100], 10, 3 ] <> "_" <> IntegerString[ Round[stellationLevel * 100], 10, 3 ];

getGenerator[p_, q_] := Module[
	{inner01, inner02, inner12, signature, p0, p1, p2, otherp2, ch2psi},

	(* chi: p0 and p2 *)
	inner02 = Cot[Pi/p]*Cot[Pi/q];
	(* psi: p1 and p2 *)
	inner12 = Cos[Pi/q]/Sin[Pi/p];
	(* phi: p0 and p1 *)
	inner01 = Cos[Pi/p]/Sin[Pi/q];

	signature = Sign[1/2-1/p-1/q];
	(* signature = 1 for hyperbolic, -1 for spherical, 0 for planar *)

	p0 = {inner02, 
		Sqrt[signature*(inner02^2-1)], 
		0}//Simplify;
	p1 = {inner12, 
		Sqrt[signature*(inner12^2-1)] Cos[Pi/p], 
		Sqrt[signature*(inner12^2-1)] Sin[Pi/p]}//Simplify;
	(* other p2 such that the midpoint of p2 and otherp2 is p1 *)
	p2 = {1, 0, 0};

	ch2psi = 2 * inner12 ^ 2 - 1;
	(* is 1 for {3,6} *)
	otherp2 = {ch2psi, 
		Sqrt[signature*(ch2psi^2-1)] Cos[Pi/p], 
		Sqrt[signature*(ch2psi^2-1)] Sin[Pi/p]};
	

	mirror1 = {0, 0, 1};
	mirror2 = {0, -Sin[Pi/p], Cos[Pi/p]};
	mirror3 = otherp2 - p2//Simplify;
	If[signature == 0,
		p0 = {1, 1, 0};
		p1 = {1, Cos[Pi/p], Sin[Pi/p]}*Cos[Pi/p];
		p2 = {1, 0, 0};
		otherp2 = 2 p1 - p2;
		mirror3 = {-Cos[Pi/p], Cos[Pi/p], Sin[Pi/p]};
	];

	vertex1 = p0;

	If[signature < 0,
		dihedralSpherical = ArcCos[Dot[p2, otherp2]/Norm[p2]/Norm[otherp2]]
	];

	If[signature > 0,
		dihedralHyperbolic = ArcCosh[HInner[p2, otherp2, signature]/HNorm[p2, signature]/HNorm[otherp2, signature]]
	];

	mirrors = {mirror1, mirror2, mirror3}//N;

	{vertex1, {mirror1, mirror2, mirror3}//N, signature}
];

generateFaces[p_, q_] := Module[
	{orderedFaces, fid, faces, face, generator, vertex1, mirrors, signature, face1, nGenerations},

	generator = getGenerator[p, q];
	vertex1 = generator[[1]];
	mirrors = generator[[2]];
	signature = generator[[3]];

	face1 = {vertex1}//N;
	finished = False;
	For[i = 0, i < 20 && finished == False, i++,
		newVertex = FullSimplify[HDoubleReflect[face1[[-1]], mirrors[[1]], mirrors[[2]], signature]];
		If[!(ApproxSamePoint[newVertex, face1[[1]]]),
			AppendTo[face1, newVertex],
			finished = True;
		]
	];

	Print["Each face contains " <> IntegerString[Length[face1]] <> " vertices."];

	nGenerations = 7;
	If[signature > 0, nGenerations = 7];
	If[signature < 0, nGenerations = 4];

	faces = {face1};
	countStart = -1;
	For[i = 0, i <= nGenerations && countStart != Length[faces], i++,
		countStart = Length[faces];
		For[mirrorIndex = 3, mirrorIndex >= 1, mirrorIndex--,
			newFaces = Map[HReflect[#, mirrors[[mirrorIndex]] , signature ]&, faces, {2}];
			faces = Union[faces, newFaces, SameTest -> sameCenter];
		];
	];

	(* Making it symmetric *)
	centeredMirrors = Select[mirrors, #[[1]] == 0 &];

	countStart = -1;
	For[i = 0, i < 20 && countStart != Length[faces], i++,
		countStart = Length[faces];
		For[mirrorIndex = Length[centeredMirrors], mirrorIndex >= 1, mirrorIndex--,
			newFaces = Map[HReflect[#, centeredMirrors[[mirrorIndex]], signature ]&, faces, {2}];
			faces = Union[faces, newFaces, SameTest -> sameCenter];
		];
	];

	orderedFaces = {};
	For[fid=1,fid<=Length[faces],fid++,
		face = faces[[fid]];
		faceCenter=Mean[face];
		If[ Dot[faceCenter, Cross[face[[1]], face[[2]]] ] < 0,
			face=Reverse[face]
		];
		AppendTo[orderedFaces, face];
	];

	Print["Number of faces: " <> IntegerString[Length[orderedFaces]] ];
	orderedFaces
];

doubleFaces[face_] := Flatten[ Map[{#[[1]], Mean[#] }&, getEdgesFromFace[face]], 1];
stellateFace[halfEdges_, r_, level_] := Module[
	{output, eid, direction, nextEid, segment1, segment2, normal1, normal2, intDirection, normal1b, int},
	output = {};
	If[r == 1, output = halfEdges];
	If[r > 1,
		For[eid = 1, eid <= Length[halfEdges], eid++,
		  (* norm = Norm[halfEdges[[1]][[1]]]; *)
		  direction = If[EvenQ[eid], 1, -1];
		  nextEid = 
		   Mod[eid + direction + 2 direction (r - 1) - 1, 
		     Length[halfEdges]] + 1;
		  segment1 = halfEdges[[eid]];
		  segment2 = halfEdges[[nextEid]];
		  If[EvenQ[eid], segment1 = Reverse[segment1]];
		  If[EvenQ[nextEid], segment2 = Reverse[segment2]];
		  normal1 = normalize[Apply[Cross, segment1], norm];
		  normal2 = normalize[Apply[Cross, segment2], norm];
		  intDirection = normalize[Cross[normal1, normal2], norm];
		  normal1b = normalize[Cross[intDirection, segment1[[1]]], norm];
		  int = If[normal1 . normal1b > 0, intDirection, -intDirection];
		  betweenInt1 = level * int + (1-level) * segment1[[1]];
		  betweenInt2 = level * int + (1-level) * segment2[[1]];
		  AppendTo[output, {betweenInt1, segment1[[2]]}];
		  If[level < 1 && EvenQ[eid],
			  AppendTo[output, {betweenInt1, betweenInt2}];
		  ];
		  (* AppendTo[output, {int, segment1[[2]]}]; *)
	  ];
	];

	output
];


elements3D[faces_, stellationLevel_, spinAngle_, sig_] := Module[
	{allEdges, edges, allVertices, vertices, ratio, selectedFaces, edgeGroups},

	rotation = RotationMatrix[spinAngle, {0, 0, 1}];
	selectedFaces = Map[(#.rotation) &, faces, {2}];
	nonRotatingFaceCenters = Map[Mean, faces];
	faceCenters = Map[Mean, selectedFaces];
	selectedFaces = Map[doubleFaces, selectedFaces];
	ratio = projectionRatio;
	If[stellateAllFaces, ratio = projectionRatio (1 - stellationLevel) + stellationLevel * maxProjectionRatio ];

	(* highlightDirection = lightSource; *)
	highlightDirection = {0.2, -0.2, 1};

	inners = Map[N[#.highlightDirection] &, nonRotatingFaceCenters];

	edgeGroups = Map[getEdgesFromFace, selectedFaces];
	highlightedFaceId = Ordering[inners, -1][[1]];
	
	If[stellateAllFaces,
		edgeGroups = Map[stellateFace[#, r, stellationLevel]&, edgeGroups],
		edgeGroups[[highlightedFaceId]] = stellateFace[edgeGroups[[highlightedFaceId]], r, stellationLevel];
	];

	displayEdges = {};
	For[fid = 1, fid <= Length[edgeGroups], fid++,
		face = edgeGroups[[fid]];
		faceCenter = faceCenters[[fid]];
		oppositeCenter = -faceCenter;
		oppositeCenter = oppositeCenter/Norm[oppositeCenter]*Norm[face[[1]][[1]] ];

		splitEdges = Flatten[ Map[splitEdge[#, splitEdgeParts]&, face], 1];
		splitEdges = Map[normalize[#, norm]&, splitEdges, {2}];
		If[fid == highlightedFaceId || stellateAllFaces,
			splitEdges = Map[partialProjection[#, oppositeCenter, norm, ratio ]&, splitEdges, {2}];
		];
		displayEdges = Join[displayEdges, splitEdges];
	];

(* 	allEdges = Flatten[edgeGroups, 1];
	edges = Union[allEdges , SameTest -> sameEdge];

	splitEdges = Flatten[ Map[splitEdge[#, splitEdgeParts]&, edges], 1];
	splitEdges = Map[normalize[#, norm]&, splitEdges, {2}];


	displayEdges = splitEdges;
 *)
	allVertices = Round[Flatten[displayEdges, 1], epsilon];
	vertices = Union[allVertices , SameTest -> ApproxSamePoint];
	verticesTally = Tally[allVertices];
	verticesTallyCounts = Map[#[[2]]&, verticesTally];
	tallyTally = Tally[verticesTallyCounts];
	(* Print["There are " <> IntegerString[Length[vertices]] <> " vertices in total."]; *)
	Print[Map[Length, {faces, allEdges, edges, allVertices, vertices}]];
	Print[tallyTally];

	range = If[stereographicProjection, 4.5, 1];
	(* range = (1 + projectionRatio); *)
	thickness = 0.01;
	viewCenter = {0, 0, 0};

	elements = {};

	If[showEdges,
		AppendTo[elements, {
			Opacity[1], FaceForm[White], Map[Cylinder[#, thickness]&, displayEdges]
		}];
	];

	graph = Graphics3D[
		elements,
		ViewPoint -> If[stereographicProjection, faceCenters[[highlightedFaceId]] * 100, {50, -50, 20}],
		ViewVertical -> {0, 0, 1},
		PlotRange -> {{viewCenter[[1]]-range, viewCenter[[1]]+range}, {viewCenter[[2]]-range, viewCenter[[2]]+range}, {viewCenter[[3]]-range, viewCenter[[3]]+range}},
		Lighting -> lighting
	];

	graph
];

exportFrame[faces_, stellationLevel_, spinAngle_, frameIndex_, outputFolderName_] := Module[
	{},

	(* Return[]; *)
	(* If[frameIndex <= 248, Return[]]; *)
	(* If[EvenQ[frameIndex] == True, Return[]]; *)
	(* If[EvenQ[frameIndex] == False, Return[]]; *)
	graph = elements3D[faces, stellationLevel, spinAngle, -1];
	testing = (outputFolderName == "test");

	outputFolder = FileNameJoin[{imageFolder, outputFolderName}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];

	outputFileName = "spinning_frame_" <> IntegerString[frameIndex, 10, 4] <> ".png";
	If[testing, outputFileName = shapeWithParams <> ".png"];
	outputFileName = FileNameJoin[{outputFolder, outputFileName}];

	cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

	If[exportToPov,
	  If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
	  POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize, RenderOptions -> "+A0.001 -J +UA"];
	  Run[cropCommand];
	  ,
	  Export[outputFileName, graph];
	];
	Print["Saved an image to " <> outputFileName];

];

exportAnimation[] := Module[
	{
		outputFolder,
		gifFileName,
		gifFolder,
		maxExplosionFactor,
		explodeStep,
		explosionFactors,
		frameIndex,
		explosionFactor,
		gifCommand,
		edges
	},

	outputFolderName = shapeWithParams <> "_spinning_frames";
	outputFolder = FileNameJoin[{imageFolder, outputFolderName}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];

	gifFileName = shapeWithParams <> "_stellating";
	gifFolder = FileNameJoin[{imageFolder, shape}];
	If[!DirectoryQ[gifFolder], CreateDirectory[gifFolder]];

	faces = generateFaces[p, q];

	stellationLevels = Table[k/(frameCount-1), {k, 0, frameCount-1}];
	If[stellateAllFaces==False,
		stellationLevels = Join[stellationLevels, Reverse[stellationLevels]],
		stellationLevels = Join[stellationLevels, Table[1, {k, Length[stellationLevels]}]];
	];

	For[frameIndex = 1, frameIndex <= Length[stellationLevels], frameIndex++,
		spinAngle = (frameIndex-1)/(Length[stellationLevels]-1) * 2 * Pi;
		stellationLevel = stellationLevels[[frameIndex]];
		Print["exporting frame " <> IntegerString[frameIndex] <> " / " <> IntegerString[Length[stellationLevels]] ];
		exportFrame[faces, stellationLevel, spinAngle, frameIndex, outputFolderName];
	];

	delay = If[Length[stellationLevels] >= 50, 3, Floor[500/Length[stellationLevels]]];

	loopBack = False;

  gifCommand = If[loopBack, 
  	"magick convert -duplicate 1,-2-1 -quiet +repage -alpha remove -loop 0 -delay ",
		"magick convert -quiet +repage -alpha remove -loop 0 -delay " ]
		<> IntegerString[delay] <> " -dispose 2 " <> outputFolder <> "\\spinning_frame*.png " <> gifFolder <> "\\" <> gifFileName <> ".gif";

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

faces = generateFaces[p, q];

adjacentFaces[f1_,f2_] := Length[Intersection[f1, f2, SameTest -> ApproxSamePoint]] == 2;
adjacentFacesIndex[faces_, id1_, id2_] := adjacentFaces[faces[[id1]], faces[[id2]]];
adjMatrix = Table[If[adjacentFacesIndex[faces, id1, id2], 1, 0], {id1, 1, Length[faces]}, {id2, 1, Length[faces]}];
Print[adjMatrix];

graph = AdjacencyGraph[Range[Length[adjMatrix]], adjMatrix ];
spanningTree = FindSpanningTree[DirectedGraph[graph]];
tree = GraphTree[spanningTree];

rotationSchedule = {};
buildSchedule[t_, schedule_, level_] := 
  Module[{subtrees, subtreeId, newSchedule},
   newSchedule = schedule;
   subtrees = TreeChildren[t];
   For[subtreeId = 1, subtreeId <= Length[subtrees], subtreeId++,
    subtree = subtrees[[subtreeId]];
    subtreeAllData = Map[#[[1]] &, VertexList[TreeGraph[subtree]]];
    newSchedule = 
     Append[newSchedule, {TreeData[t], TreeData[subtree], level, 
       subtreeAllData}];
    newSchedule = buildSchedule[subtree, newSchedule, level + 1];
    ];
   newSchedule
   ];

rotationSchedule = buildSchedule[tree, rotationSchedule, 1];
Print[rotationSchedule];



exportFrame[faces, 1, 0, 1, "test"];

(* exportAnimation[]; *)


(* 

for ($num = 69 ; $num -le 99 ; $num++) { cp spinning_frame_0068.png "spinning_frame_00$num.png" }

 *)