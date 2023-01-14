#!/usr/bin/env wolframscript

exportToPov = True;
highlightCenter = False;

topView = True;
topView = False;

showEdges = True;
(* showEdges = False; *)

stellateAllFaces = True;
stellateAllFaces = False;

stereographicProjection = True;
stereographicProjection = False;

(* projectionRatio = 0.003; *)

(* projectionRatio = 0: touches the sphere. = 1: projected to a plane *)
projectionRatio = .01;
(* projectionRatio = 0.12; *)
maxProjectionRatio = 0.1;

stellationLevel = 1;

imageSize = {4, 3} * 720 / 3;
lightSource = {50,-50,50};
lighting = {{"Point", White, lightSource}};

(* stageCount = 1; *)
stageCount = 2;

(* frameCount = 2; *)
(* frameCount = 5; *)
frameCount = 10;
(* frameCount = 12; *)
(* frameCount = 150; *)
(* frameCount = 200; *)
(* frameCount = 220; *)

(* suboptimal = True; *)
suboptimal = False;

argv = Rest @ $ScriptCommandLine;
If[Length[argv] >= 2, 
	p = ToExpression[argv[[1]]]; q = ToExpression[argv[[2]]],
	p = 3; q = 4; (* default *)
];

If[Length[argv] >= 3, 
	r = ToExpression[argv[[3]]],
	r = 1; (* default *)
];

If[p <= 4, r = 1];
If[p == 4, stageCount = 1];

allColors = Join[{Lighter[Blue, 0.3], Lighter[Green, 0.4], Orange, Purple, Yellow, Cyan, Magenta, Brown, Pink, Red, Blue, Green}, RandomColor[100]];

colorMap = <|
	3 -> Yellow,
	5 -> Red
|>;

splitEdgeParts = 2;

colorGroup = {Red, Blue, Green, Yellow, Magenta, Cyan, Brown, Orange};
colors = Join[colorGroup, Map[Darker[#, 0.5]&, colorGroup], Map[Lighter[#, 0.5]&, colorGroup]];

maxStellationLevel = If[Length[argv] >= 3, ToExpression[argv[[3]]], 1];
maxRatio = Tan[maxStellationLevel Pi/p]/Tan[Pi/p];
nGenerations = If[Length[argv] >= 4, ToExpression[argv[[4]]], 4];
dihedralSpherical = 0;
dihedralHyperbolic = 0;

shape = "unfold_id_" <> IntegerString[stageCount];


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
smoothFall[x_, start_, duration_] := If[x < start, 1, If[x > start + duration, 0, (1 + Cos[(x - start)/duration*Pi])/2]];
smoothFallFromTo[x_, start_, duration_, from_, to_] := smoothFall[x, start, duration] (from - to) + to;
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

scaleFace[face_, stellationLevel_] := Module[
	{ratio, edges, edgeOrders},
	ratio = Tan[stellationLevel Pi/p]/Tan[Pi/p];
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

shapeWithParams = shape <> "_" <> IntegerString[frameCount] <> If[suboptimal, "_suboptimal", ""];

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


elements3D[faces_, stellationLevel_, spinAngle_, sig_, range_] := Module[
	{allEdges, edges, allVertices, vertices, ratio, selectedFaces, edgeGroups},

	rootFaceCenterInner = Dot[rootFaceCenter, {0, 0, -1}]/Norm[rootFaceCenter];
	If[Abs[rootFaceCenterInner] > 1 - epsilon,
		If[rootFaceCenterInner > 0,
			staticOrientation = IdentityMatrix[3],
			staticOrientation = RotationMatrix[Pi, {0, 1, 0}]
		],
		staticOrientation = RotationMatrix[{rootFaceCenter, {0, 0, -1}}]
	];

	rotation = RotationMatrix[spinAngle, {0, 0, 1}].staticOrientation;
	selectedFaces = Map[(rotation.#) &, faces, {2}];
	allEdges = Flatten[Map[getEdgesFromFace, selectedFaces], 1];
	edges = Union[allEdges , SameTest -> sameEdge];

	faceCenters = Map[Mean, selectedFaces];
	allVertices = Flatten[edges, 1];
	vertices = Union[allVertices , SameTest -> ApproxSamePoint];
	Print["vertices count"];
	Print[vertices//Length];

	viewCenter = Mean[faceCenters];
	thickness = 0.01 * range;
	opacity = 1;

	elements = {
			Table[{
				Opacity[opacity], FaceForm[allColors[[k]]], Polygon[selectedFaces[[k]] * (1 + 0.0001 k)]
			}, {k, Length[selectedFaces]}],
			{
				Opacity[1], FaceForm[White], Map[Cylinder[#, thickness]&, edges]
			},
			{
				Opacity[1], FaceForm[White], Map[Sphere[#, thickness * 1.5]&, vertices]
			}
	};

	graph = Graphics3D[
		elements,
		ViewPoint -> {50, -50, 40},
		ViewVertical -> {0, 0, 1},
		PlotRange -> {{viewCenter[[1]]-range, viewCenter[[1]]+range}, {viewCenter[[2]]-range, viewCenter[[2]]+range}, {viewCenter[[3]]-range, viewCenter[[3]]+range}},
		Lighting -> lighting
	];

	graph
];

foldFaces[faces_, rotationSchedule_, foldPercents_] := Module[
	{originalDihedralAngle, rotatedFaces, scheduleId, level, schedule, face1Id, face2Id, rotatedFaceIds},
	originalDihedralAngle = 0;
	rotatedFaces = faces;

	For[scheduleId = 1, scheduleId <= Length[rotationSchedule],scheduleId++,
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
			If[Length[pivot] != 2,
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
			gidtidDihedralAngle = ArcCos[Sqrt[ (5 - 2 * Sqrt[5])/15 ]]//N;
			(* Print[originalDihedralAngle / Pi * 180]; *)
			(* Print[gidtidDihedralAngle / Pi * 180]; *)
			
			angleToFlat = Pi - originalDihedralAngle;
			(* angleToStellate = gidtidDihedralAngle - originalDihedralAngle; (* 79.19 deg *) *)
			(* angleToStellate = Pi - gidtidDihedralAngle - originalDihedralAngle; (* 100.81 deg *) *)
			angleToStellate = Pi - originalDihedralAngle - originalDihedralAngle; (* 37.38 deg *)

			perc = foldPercents[[level]];
			angleToTarget = If[perc >= 0, angleToFlat, angleToStellate];
			rotationAngle = angleToTarget * Abs[perc];

			If[perc < -1,
				realPerc = Abs[perc + 1];
				rotationAngle = realPerc * angleToFlat + (1 - realPerc) * angleToStellate;
			];

			(* Print[{angleToFlat + originalDihedralAngle, angleToStellate + originalDihedralAngle,  rotationAngle + originalDihedralAngle}  * 180.0/Pi]; *)
			rotMatrix = RotationMatrix[rotationAngle, {relativeFace2, relativeFace1}];
			(* Print[{ originalDihedralAngle, angleToStellate, originalDihedralAngle + angleToStellate } * 180.0/Pi]; *)
			(* Print[rotMatrix]; *)

			For[fid = 1, fid <= Length[rotatedFaceIds], fid++,
				faceId = rotatedFaceIds[[fid]];
				(* Print["rotating face " <> IntegerString[faceId]]; *)
				rotatedFace = rotatedFaces[[faceId]];
				rotatedFace = Map[((# - pivotCenter).rotMatrix + pivotCenter)&, rotatedFace];
				rotatedFaces[[faceId]] = rotatedFace;
			];
		];
	];

	Print[{angleToFlat + originalDihedralAngle, angleToStellate + originalDihedralAngle,  rotationAngle + originalDihedralAngle}  * 180.0/Pi];
	rotatedFaces
];

exportFrame[faces_, rotationSchedule_, foldPercents_, stellationLevel_, spinAngle_, frameIndex_, outputFolderName_] := Module[
	{},

	(* Return[]; *)
	(* If[frameIndex <= 248, Return[]]; *)
	(* If[EvenQ[frameIndex] == True, Return[]]; *)
	(* If[EvenQ[frameIndex] == False, Return[]]; *)

	rotatedFaces = foldFaces[faces, rotationSchedule, foldPercents];
	(* rotatedFaces = Select[rotatedFaces, Length[#] == 4 &]; *)
	triangleIds = Select[Range[Length[rotatedFaces]], Length[ rotatedFaces[[#]] ] == 3 & ];
	squareIds = Select[Range[Length[rotatedFaces]], Length[ rotatedFaces[[#]] ] == 4 & ];

	rotatedFaceCenters = Map[Mean, rotatedFaces ];
	rotatedFaceCentersTally = Tally[rotatedFaceCenters, ApproxSamePoint[#1, #2]&];
	faceTallyCounts = Sort[Map[#[[2]]&, rotatedFaceCentersTally], Greater];
	(* rotatedCenter = Mean[rotatedFaceCenters[[squareIds]] ]; *)

(* 	Map[Print[ (# - rotatedCenter)/0.2071067811865478 ]&, rotatedFaceCenters[[squareIds]]  ];
	Print[];
	Map[Print[ (# - rotatedCenter)/0.2071067811865478 ]&, rotatedFaceCenters[[triangleIds]]  ];
	Exit[]; *)

	Print["face tallies"];
	Print[faceTallyCounts];
	Print[faceTallyCounts//Length];

	rotatedEdges = Flatten[Map[getEdgesFromFace, rotatedFaces], 1];
	rotatedEdgeCenters = Map[Mean, rotatedEdges];
	rotatedEdgeCentersTally = Tally[rotatedEdgeCenters, ApproxSamePoint[#1, #2]&];
	edgeTallyCounts = Sort[Map[#[[2]]&, rotatedEdgeCentersTally], Greater];
	Print["edge tallies"];
	Print[edgeTallyCounts];
	Print[edgeTallyCounts//Length];

	faceCenters = Map[Mean, rotatedFaces];
	radius = Max[Norm/@faceCenters];
	range = radius * 0.9;
	Print["range = " <> ToString[range]];

	(* range = If[Max[foldPercents] > 0, Max[foldPercents] * 2 + 1, 1] + 0.4 (r - 1); *)

	graph = elements3D[rotatedFaces, stellationLevel, spinAngle, -1, range];
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

adjacentFaces[f1_,f2_] := Length[Intersection[f1, f2, SameTest -> ApproxSamePoint]] == 2;
adjacentFacesIndex[faces_, id1_, id2_] := adjacentFaces[faces[[id1]], faces[[id2]]];

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

	gifFileName = shapeWithParams;
	gifFolder = FileNameJoin[{imageFolder, shape}];
	If[!DirectoryQ[gifFolder], CreateDirectory[gifFolder]];

	(* faces = generateFaces[p, q]; *)
	polygons = PolyhedronData["Icosidodecahedron", "Polygons"];
	faces = Map[First, polygons]//N;
	norms = Map[Norm, faces, {2}];
	maxNorm = Max[Flatten[norms]];
	faces = faces/maxNorm;

	For[fid = 1, fid <= Length[faces], fid++,
		face = faces[[fid]];
		allColors[[fid]] = colorMap[Length[face]];
	];

(* 	adjMatrix = Table[If[adjacentFacesIndex[faces, id1, id2], 1, 0], {id1, 1, Length[faces]}, {id2, 1, Length[faces]}];
	Print[adjMatrix];

	graph = AdjacencyGraph[Range[Length[adjMatrix]], adjMatrix ];
 *)
 (* 
	optimized only for 79.19: non convex shape: Gidtid
  *)
	(* edgeList = {1 \[UndirectedEdge] 2, 1 \[UndirectedEdge] 3, 1 \[UndirectedEdge] 4, 1 \[UndirectedEdge] 6, 2 \[UndirectedEdge] 13, 3 \[UndirectedEdge] 14, 4 \[UndirectedEdge] 15, 5 \[UndirectedEdge] 16, 7 \[UndirectedEdge] 16, 7 \[UndirectedEdge] 30, 8 \[UndirectedEdge] 31, 10 \[UndirectedEdge] 28, 11 \[UndirectedEdge] 29, 12 \[UndirectedEdge] 7, 12 \[UndirectedEdge] 8, 12 \[UndirectedEdge] 26, 13 \[UndirectedEdge] 9, 13 \[UndirectedEdge] 27, 14 \[UndirectedEdge] 10, 15 \[UndirectedEdge] 11, 16 \[UndirectedEdge] 25, 17 \[UndirectedEdge] 18, 17 \[UndirectedEdge] 22, 20 \[UndirectedEdge] 31, 21 \[UndirectedEdge] 32, 23 \[UndirectedEdge] 32, 24 \[UndirectedEdge] 28, 25 \[UndirectedEdge] 29, 30 \[UndirectedEdge] 19, 31 \[UndirectedEdge] 21, 32 \[UndirectedEdge] 22}; *)
	rootFaceId = 16;

	(* optimized only for 100.81
	 *)
	edgeList = {1 \[UndirectedEdge] 3, 1 \[UndirectedEdge] 4, 1 \[UndirectedEdge] 5, 2 \[UndirectedEdge] 13, 3 \[UndirectedEdge] 14, 4 \[UndirectedEdge] 15, 5 \[UndirectedEdge] 16, 6 \[UndirectedEdge] 16, 7 \[UndirectedEdge] 30, 8 \[UndirectedEdge] 31, 9 \[UndirectedEdge] 13, 10 \[UndirectedEdge] 28, 11 \[UndirectedEdge] 29, 12 \[UndirectedEdge] 7, 12 \[UndirectedEdge] 26, 13 \[UndirectedEdge] 27, 14 \[UndirectedEdge] 23, 15 \[UndirectedEdge] 11, 15 \[UndirectedEdge] 24, 16 \[UndirectedEdge] 25, 17 \[UndirectedEdge] 19, 17 \[UndirectedEdge] 22, 22 \[UndirectedEdge] 28, 25 \[UndirectedEdge] 30, 26 \[UndirectedEdge] 31, 27 \[UndirectedEdge] 32, 28 \[UndirectedEdge] 18, 30 \[UndirectedEdge] 19, 30 \[UndirectedEdge] 20, 31 \[UndirectedEdge] 21, 32 \[UndirectedEdge] 22};
	rootFaceId = 16;

	(* -1: 30, -3: 32 *)
	edgeList = {1 \[UndirectedEdge] 2, 1 \[UndirectedEdge] 4, 1 \[UndirectedEdge] 6, 2 \[UndirectedEdge] 13, 3 \[UndirectedEdge] 14, 4 \[UndirectedEdge] 15, 5 \[UndirectedEdge] 16, 7 \[UndirectedEdge] 16, 7 \[UndirectedEdge] 30, 8 \[UndirectedEdge] 12, 8 \[UndirectedEdge] 31, 9 \[UndirectedEdge] 32, 10 \[UndirectedEdge] 28, 11 \[UndirectedEdge] 29, 13 \[UndirectedEdge] 27, 14 \[UndirectedEdge] 10, 14 \[UndirectedEdge] 23, 15 \[UndirectedEdge] 11, 15 \[UndirectedEdge] 24, 17 \[UndirectedEdge] 18, 17 \[UndirectedEdge] 19, 17 \[UndirectedEdge] 22, 18 \[UndirectedEdge] 29, 20 \[UndirectedEdge] 31, 21 \[UndirectedEdge] 32, 22 \[UndirectedEdge] 28, 23 \[UndirectedEdge] 32, 25 \[UndirectedEdge] 29, 26 \[UndirectedEdge] 30, 27 \[UndirectedEdge] 31, 30 \[UndirectedEdge] 19};
	rootFaceId = 1;

	(* -1, -2, -3 are 29, 32, 32, respectively *)
	edgeList = {1 \[UndirectedEdge] 3, 1 \[UndirectedEdge] 4, 1 \[UndirectedEdge] 6, 2 \[UndirectedEdge] 12, 2 \[UndirectedEdge] 13, 3 \[UndirectedEdge] 14, 4 \[UndirectedEdge] 15, 5 \[UndirectedEdge] 16, 7 \[UndirectedEdge] 16, 7 \[UndirectedEdge] 30, 8 \[UndirectedEdge] 31, 10 \[UndirectedEdge] 28, 11 \[UndirectedEdge] 29, 12 \[UndirectedEdge] 8, 12 \[UndirectedEdge] 26, 13 \[UndirectedEdge] 9, 13 \[UndirectedEdge] 27, 14 \[UndirectedEdge] 10, 15 \[UndirectedEdge] 11, 15 \[UndirectedEdge] 24, 16 \[UndirectedEdge] 25, 17 \[UndirectedEdge] 19, 17 \[UndirectedEdge] 20, 18 \[UndirectedEdge] 29, 20 \[UndirectedEdge] 31, 22 \[UndirectedEdge] 28, 23 \[UndirectedEdge] 32, 25 \[UndirectedEdge] 29, 27 \[UndirectedEdge] 32, 30 \[UndirectedEdge] 19, 31 \[UndirectedEdge] 21};
	rootFaceId = 1;

	(* 32, 32, 29 *)
	edgeList = {1 \[UndirectedEdge] 4, 1 \[UndirectedEdge] 6, 2 \[UndirectedEdge] 12, 2 \[UndirectedEdge] 13, 3 \[UndirectedEdge] 13, 4 \[UndirectedEdge] 15, 5 \[UndirectedEdge] 16, 7 \[UndirectedEdge] 16, 8 \[UndirectedEdge] 31, 9 \[UndirectedEdge] 14, 10 \[UndirectedEdge] 28, 11 \[UndirectedEdge] 29, 12 \[UndirectedEdge] 8, 12 \[UndirectedEdge] 26, 13 \[UndirectedEdge] 9, 14 \[UndirectedEdge] 10, 14 \[UndirectedEdge] 23, 15 \[UndirectedEdge] 24, 16 \[UndirectedEdge] 25, 17 \[UndirectedEdge] 18, 17 \[UndirectedEdge] 20, 17 \[UndirectedEdge] 22, 19 \[UndirectedEdge] 29, 19 \[UndirectedEdge] 30, 21 \[UndirectedEdge] 32, 24 \[UndirectedEdge] 28, 25 \[UndirectedEdge] 29, 27 \[UndirectedEdge] 31, 30 \[UndirectedEdge] 20, 31 \[UndirectedEdge] 21, 32 \[UndirectedEdge] 22};
	rootFaceId = 12;

	spanningTree = FindSpanningTree[Graph[edgeList]];

	pentagonIds = Select[Range[Length[faces]], Length[faces[[#]]]==5 &];
	Print[pentagonIds];
	treeHeights = Map[TreeDepth[GraphTree[spanningTree, #]]&, pentagonIds];
	Print[treeHeights];

	tree = GraphTree[spanningTree, rootFaceId];

	rotationSchedule = {};
	rotationSchedule = buildSchedule[tree, rotationSchedule, 1];

	rootFaceCenter = Mean[faces[[rootFaceId]]];
	Print["root face side count"];
	Print[IntegerString[ Length[faces[[rootFaceId]] ]]];

	maxLevel = Max[Map[#[[3]]&, rotationSchedule ]];

	(* unfoldPercents = Table[k/(frameCount-1), {k, 0, frameCount-1}]; *)
	unfoldPercents = Table[smoothFall[x, k/2/maxLevel - 1/4/maxLevel, 1/2]//N, {x, 0, 1, 1/(frameCount-1)}, {k, maxLevel}];

	angleToFlat = Pi - originalDihedralAngle;
	(* angleToStellate = gidtidDihedralAngle - originalDihedralAngle; (* 79.19 deg *) *)
	(* angleToStellate = Pi - gidtidDihedralAngle - originalDihedralAngle; (* 100.81 deg *) *)
	angleToStellate = Pi - originalDihedralAngle - originalDihedralAngle; (* 37.38 deg *)

	angle142 = ArcCos[-Sqrt[ (5 + 2 * Sqrt[5])/15 ]]//N; (* 142.62 , id dihedral angle*)
	angle79 = ArcCos[Sqrt[ (5 - 2 * Sqrt[5])/15 ]]//N; (* 79.19 , gidtid dihedral angle*)
	angle100 = Pi - angle79; (* 100.81 *)
	angle37 = Pi - angle142; (* 37.38 *)

	Print[{angle142, angle100, angle79, angle37}/Pi * 180];

	step1 = (angle142 - angle100)/(angle142 - angle37);
	step2 = (angle100 - angle79)/(angle142 - angle37);
	step3 = (angle79 - angle37)/(angle142 - angle37);
	negativePercents = Join[
		Table[smoothFallFromTo[x, 0, 1, 0, -step1], {x, 0, 1, 1/(frameCount/2 - 1)}, {k, maxLevel}],
		Table[-step1, {x, 0, 1, 1/(frameCount/2 - 1)}, {k, maxLevel}],
	  Table[smoothFallFromTo[x, 0, 1, -step1, -step1 - step2], {x, 0, 1, 1/(frameCount/2 - 1)}, {k, maxLevel}], 
	  Table[-step1 - step2, {x, 0, 1, 1/(frameCount/2 - 1)}, {k, maxLevel}],
	  Table[smoothFallFromTo[x, 0, 1, -step1 - step2, -1], {x, 0, 1, 1/(frameCount/2 - 1)}, {k, maxLevel}]
  ]//N;

	minusOnes = Table[-1.0, {x, 0, 1, 1/(frameCount/4 - 1)}, {k, maxLevel}];
	zeros = Table[-0.0, {x, 0, 1, 1/(frameCount/4 - 1)}, {k, maxLevel}];

	unfoldPercents = Join[unfoldPercents, zeros, negativePercents, minusOnes ];
	
	(* unfoldPercents = Join[unfoldPercents, Reverse[unfoldPercents]]; *)

	If[r > 1,
		unfoldPercents = Map[Min[#, 0.99]&, unfoldPercents, {2}];
	];

	Print[unfoldPercents];

	For[frameIndex = 1, frameIndex <= Length[unfoldPercents], frameIndex++,
		(* If[frameIndex != 1 && frameIndex != 10 && frameIndex != 15 && frameIndex != 20 && frameIndex != 25, Continue[]]; *)
		(* If[frameIndex != 1 && frameIndex != 20, Continue[]]; *)
		(* If[frameIndex < 10, Continue[]]; *)
		unfoldPercent = unfoldPercents[[frameIndex]];
		Print["exporting frame " <> IntegerString[frameIndex] <> " / " <> IntegerString[Length[unfoldPercents]] ];
		(* exportFrame[faces, rotationSchedule, 1, spinAngle, frameIndex, outputFolderName]; *)
		spinAngle = Pi/2 - frameIndex/Length[unfoldPercents] * 2 * Pi + Pi/5;
		exportFrame[faces, rotationSchedule, unfoldPercent, 1, spinAngle, frameIndex, outputFolderName];
	];

	Exit[];

	delay = If[Length[unfoldPercents] >= 50, 3, Floor[500/Length[unfoldPercents]]];

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

(* faces = generateFaces[p, q];

adjMatrix = Table[If[adjacentFacesIndex[faces, id1, id2], 1, 0], {id1, 1, Length[faces]}, {id2, 1, Length[faces]}];
Print[adjMatrix];

graph = AdjacencyGraph[Range[Length[adjMatrix]], adjMatrix ];
spanningTree = FindSpanningTree[DirectedGraph[graph]];
tree = GraphTree[spanningTree];
rootFaceId = TreeData[tree];
rootFaceCenter = Mean[faces[[rootFaceId]]];

rotationSchedule = {};

rotationSchedule = buildSchedule[tree, rotationSchedule, 1];
Print[rotationSchedule];
 *)
(* exportFrame[faces, rotationSchedule, {10, 50, 100}, 1, 0, 1, "test"]; *)
(* exportFrame[faces[[ {1,2,3,4,5,6,7,8,9,10,12} ]], 1, 0, 2, "test"]; *)

exportAnimation[];

(* 
180: flat net
142.62: icosidodecahedron
100.81: icosahedron + great dodecahedron
79.19: non convex shape: Gidtid. https://en.wikipedia.org/wiki/Great_ditrigonal_icosidodecahedron
37.38: another icosahedron + great dodecahedron

It's not clear if the 100.81 shape and 37.38 shape can achieve "full faces" at the same time.
Answer: Not always.

 *)

(* 

for ($num = 69 ; $num -le 99 ; $num++) { cp spinning_frame_0068.png "spinning_frame_00$num.png" }

 *)