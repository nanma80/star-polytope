#!/usr/bin/env wolframscript

(*
mogrify -crop 450x450+75+0 -path . pov_*.png
mogrify -crop 300x300+50+0 -path . explode*.gif

magick convert -duplicate 1,-2-1 -quiet +repage -alpha remove -loop 0 -delay 5 -dispose 2 *.png out.gif
magick convert out.gif -coalesce -duplicate 1,-2-1 -quiet -layers OptimizePlus  -loop 0 cycle.gif
python -m SimpleHTTPServer 8000

*)

(* global config *)

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
	(* "polytope_3_4_3", *)
	"polytope_5_3_3_cell120"
	(* "polytope_3_3_5_cell600", *)
	(* "bitruncated_3_4_3" *)
};
(*shape = "test";*)

(* exportToPov = False; *)
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

roundPrecision = 0.000001;
phi = (1 + Sqrt[5])/2;
viewPoint = {0.75, 1.5, 0.5};
(* viewPoint = {1, -0.5, 0.15}; *)

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
getCellCenter[cell_] := Simplify[Mean[Flatten[cell, 1]]];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
explodedCell[cell_, explosionFactor_] := Map[
	(# + Mean[Map[Mean,cell]]*(Norm[First[First[cell]]//N]/Norm[Mean[Map[Mean,cell]]//N])^1.5 * explosionFactor)&, 
	cell, {2}];
normalizedAngle[u_, v_] := ArcSin[u.v/Norm[u]/Norm[v]]/Pi + 0.5;
projectToDirection[vertex4d_, projectionMatrix_] := vertex4d.Transpose[projectionMatrix];
(* perspectiveProjection[point_, fullProjectionMatrix_, wDistance_ ] := projectToDirection[point, fullProjectionMatrix[[1;;3]]] / (1 + point.(fullProjectionMatrix[[4]])/wDistance); *)
perspectiveProjection[point_, fullProjectionMatrix_, wDistance_ ] := projectToDirection[point, fullProjectionMatrix[[1;;3]]];
normalizedInner[u_, v_] := u.v/Norm[u]/Norm[v];
normalized[u_] := u/Norm[u];
doubleRotationMatrix[theta_, signature_] := ArrayFlatten[{{RotationMatrix[-theta], 0}, {0, RotationMatrix[signature * theta]}}];

getProjectionMatrix[direction_] := Simplify[Orthogonalize[{direction, {2, -1.4, 0.3, 0.9}, {0, 1, 2.3, 0.8}, {0.5, 0.3, 1, 0.1}}]][[2;;4]];

mapHopfFibration[v4d_] := Module[
	{z0, z1},
	z0 = v4d[[1]] + I v4d[[2]];
	z1 = v4d[[3]] + I v4d[[4]];
	x1 = Re[(2 z0 Conjugate[z1])];
	x2 = Im[(2 z0 Conjugate[z1])];
	x3 = Re[z0 Conjugate[z0] - z1 Conjugate[z1]];
	Round[{x1, x2, x3}, roundPrecision]
];

mapHopfFibrationMirror[v4d_] := Module[
	{z0, z1},
	z0 = v4d[[1]] - I v4d[[2]];
	z1 = v4d[[3]] - I v4d[[4]];
	x1 = Re[(2 z0 Conjugate[z1])];
	x2 = Im[(2 z0 Conjugate[z1])];
	x3 = Re[z0 Conjugate[z0] - z1 Conjugate[z1]];
	Round[{x1, x2, x3}, roundPrecision]
];

getHue[v3d_] := If[Norm[v3d[[{1, 2}]]] < 0.001, 
						If[v3d[[3]] > 0, Darker[Blue, 0.8], Lighter[Red, 0.8]],
						(* If[v3d[[3]] > 0,
							Darker[Hue[Mod[Arg[v3d[[1]] + I v3d[[2]]]/2/Pi , 1]], 0.3],
							Lighter[Hue[Mod[Arg[v3d[[1]] + I v3d[[2]]]/2/Pi , 1]], 0.3]
						] *)
						(* *0.9 to avoid to similar colors of purple *)
						(* Hue[Mod[Arg[v3d[[1]] + I v3d[[2]]]/2/Pi , 1] * 0.9] *)
						Hue[Mod[Arg[v3d[[1]] + I v3d[[2]]]/2/Pi , 1]]
];


exportImage[shape_, cells_, explosionFactor_, theta_, serialNumber_] := Module[
	{
		dataFileName,
		shapeTokens,
		color,
		cellShape,
		cellsByLayers,
		layerKeys,
		thickness,
		lighting,
		outputFolder,
		range,
		outputFileName,
		cropCommand,
		inactiveCells,
		inactiveFaces,
		inactiveEdges,
		inactiveVertices,
		activeCells,
		activeFaces,
		touchingIndices,
		notTouchingIndices,
		touchingActiveFaces,
		notTouchingActiveFaces,
		allIndices,
		activeEdges,
		activeVertices,
		graph,
		imageSize,
		faceTemp,faceNormalVector,faceCenter,projectedFaceCenter,faceVisible
	},

	shapeTokens = StringSplit[shape, "_"];
	If[Length[shapeTokens] < 3,
		color = Red,
		cellShape = shapeTokens[[2]] <> "_" <> shapeTokens[[3]];
		color = allColors[cellShape];
	];

	thickness = Norm[cells[[1]][[1]][[1]]] * 0.008;
	lighting = {{"Point", White, viewPoint * 10}};
	range = Norm[cells[[1]][[1]][[1]]] * rangeFactor;

	outputFolder = shape <> "_unfold_frames";
	outputFolder = FileNameJoin[{imageFolder, outputFolder}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];

	outputFileName = "animation_" <> shape <> "_" <> IntegerString[serialNumber, 10, 4] <> ".png";
	If[exportToPov, outputFileName = "pov_" <> outputFileName ];
	outputFileName = FileNameJoin[{outputFolder, outputFileName}];

	imageSize = imageSizes["allLayers"];
	cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

	activeCells = cells;
	Print["Selected " <> IntegerString[Length[activeCells]] <> " active cells. ExplosionFactor: " <> TextString[explosionFactor]];

	activeCells = Map[explodedCell[#, explosionFactor]&, activeCells];
	activeFaces = Flatten[activeCells, 1];
	(* activeEdges = Union[ Flatten[Map[getEdgesFromFace, activeFaces], 1], SameTest -> sameCenter]; *)
	(* activeVertices = Union[ Flatten[activeFaces,1], SameTest -> sameVertex]; *)
	activeEdges = Flatten[Map[getEdgesFromFace, activeFaces], 1];
	activeVertices = Flatten[activeFaces,1];

	(* range = range /2; *)
	(* projectedActiveFaces = Map[projectTo3d, activeFaces, {2}]; *)
	(* activeCellsCenters = Map[Total[#, 2]/Length[activeCells[[1]]]/Length[activeCells[[1]][[1]]]&, activeCells]; *)
	activeCellsCenters = Map[Total[#, 2]/Total[Map[Length, activeCells[[1]]]]&, activeCells];

	(* activeCellsCenters = Map[projectTo3d, activeCellsCenters]; *)
	(* activeCellsCenters = activeCellsCenters/Norm[activeCellsCenters[[1]]]; *)

    wDistance = Max[Flatten[activeFaces]] * 1.05 * 1000000;
    (* Print[wDistance]; *)


	(* fullProjectionMatrix = RotationMatrix[{rootCellCenter, {0, 0, 0, 1}}]; *)
	(* If[shape == "polytope_3_3_5_cell600", fullProjectionMatrix = ArrayFlatten[{{1, 0, 0}, {0, RotationMatrix[-ArcTan[Sqrt[2]]], 0}, {0, 0, 1}}].ArrayFlatten[{{IdentityMatrix[2], 0}, {0, RotationMatrix[Pi/4]}}] ]; *)

	fullProjectionMatrix = doubleRotationMatrix[theta, -1];

(* 	perspectiveProjection[activeCellsCenters[[11]], fullProjectionMatrix, wDistance]
	centers = Table[ perspectiveProjection[activeCellsCenters[[k]], fullProjectionMatrix, wDistance], {k, 120}]
	Select[centers, Norm[{#[[1]], #[[2]]}] < 0.01&]
 *)

    projectedActiveFaces = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, activeFaces, {2}];
    range = Max[Flatten[activeFaces]] * 2.3;
    range = Max[Flatten[activeFaces]] * 1.4; (* 120-cell *)

    range = If[negativeFold, 1.3, 6];
    viewPoint = {50, -50, 50};

    If[shape == "polytope_3_4_3", 
    	range = Max[Flatten[activeFaces]] * 2.2;
    	viewPoint = {1.0, -0.9, 0.5}];
    If[shape == "polytope_3_3_5_cell600", 
    	range = Max[Flatten[activeFaces]] * 1.5;
    	viewPoint = {1.2, -0.7, 0.5}];
    If[shape == "polytope_5_3_3_cell120", 
    	range = Max[Flatten[activeFaces]] * 0.8;
    	viewPoint = {1.2, -0.7, 0.5}];
	If[shape == "bitruncated_3_4_3", 
    	range = Max[Flatten[activeFaces]] * 1.1;
    	viewPoint = {1.2, -0.7, 0.5}];
    Print["range"];
    Print[range];

	rotatedActiveCellsCenters = Map[fullProjectionMatrix.#&, activeCellsCenters];

    (* edges3D = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, edgeSegments, {2}]; *)
    (* vertices3D = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, selectedEdgeEnds]; *)
    (* otherVertices3D = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, selectedVertices]; *)

    faceCellRatio = Length[activeFaces]/Length[activeCellsCenters];
    grayArea = 0.05;
    graphElements = {};
    thickness = 0.001;

    graphFaces = {};

    For[k = 1, k <= Length[activeFaces], k++,
	    cellId = Floor[(k - 1)/faceCellRatio] + 1;
	    color = cellColors[[cellId]];

		AppendTo[graphFaces,
			{
				Opacity[1],
				color,
				Polygon[ projectedActiveFaces[[k]] ]
			}
		];

    ];


    Print["draw face count: " <> IntegerString[Length[graphFaces]]];
    AppendTo[graphElements, graphFaces];
    (* thickness = 1.0; *)
    (* Print[Map[getHue[mapHopfFibration[#]]&, rotatedActiveCellsCenters]//Tally]; *)

	hopf3dCenters = Map[mapHopfFibration, rotatedActiveCellsCenters];
	(* Print[Map[#[[2]]&, hopf3dCenters//Tally//Sort]//Tally]; *)

	graph = Graphics3D[
		graphElements,
		ViewPoint -> viewPoint * 100,
		ViewVertical -> {0, 0, 1},
		PlotRange -> {{-range, range}, {-range, range}, {-range, range}},
		(* Lighting -> lighting, *)
		Boxed -> False
		(* ViewAngle -> range/Norm[viewPoint]/100/6.7 *)
	];


	If[exportToPov,
		If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
		POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize, RenderOptions -> "+A0.001 -J +UA"];
		Run[cropCommand];
		,
		Export[outputFileName, graph, ImageSize -> imageSize[[2]]];
	]
	Print["Saved the image to " <> outputFileName];
];

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

	outputFolder = shape <> "_unfold_frames";
	outputFolder = FileNameJoin[{imageFolder, outputFolder}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];
	gifFileName = shape <> "_unfold";
	gifFolder = FileNameJoin[{imageFolder, shape}];
	If[!DirectoryQ[gifFolder], CreateDirectory[gifFolder]];

	explosionConfig = explosionConfigs[shape];
	maxExplosionFactor = explosionConfig[[1]];
	frameCount = explosionConfig[[2]];
	explodeStep = maxExplosionFactor/frameCount;

	frameCount = 200;
	explosionFactor = 2.9 * If[shape == "polytope_3_3_5_cell600", 5, 1];
	explosionFactor = 0.4; (* 120-cell *)
	If[shape == "polytope_3_3_5_cell600", explosionFactor = 0.7];
	If[shape == "polytope_3_4_3", explosionFactor = 0.4];

	angleSpan = Pi/5;
    If[shape == "polytope_3_4_3", 
    	frameCount = 200;
    	angleSpan = 2 Pi/6];
    If[shape == "bitruncated_3_4_3", 
    	frameCount = 200;
    	angleSpan = 2 Pi/6];
    (* frameCount = 20; *)

    thetas = Table[(k - 1) * angleSpan / (frameCount), {k, 1, frameCount}];

    For[ frameIndex = 1, frameIndex <= Length[thetas] , frameIndex++,
        theta = thetas[[frameIndex]] * 1.0;
        Print["Frame #" <> IntegerString[frameIndex] <> "/" <> IntegerString[Length[thetas]] 
            <> " ; theta: " <> ToString[theta, InputForm]];
		exportImage[shape, explosionFactor, theta, frameIndex];
    ];

    delay = If[frameCount > 30, 3, 50];

    (* gifCommand = "magick convert -duplicate 1,-2-1 -quiet +repage -alpha remove -loop 0 -delay "  (* loop back*) *)
    gifCommand = "magick convert -quiet +repage -alpha remove -loop 0 -delay " (* no looping back *)
		<> IntegerString[delay] <> " -dispose 2 " <> outputFolder <> "\\*animation*.png " <> gifFolder <> "\\" <> gifFileName <> ".gif";

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

(* For[shapeIndex = 1, shapeIndex <= Length[shapes], shapeIndex ++,
	shape = shapes[[shapeIndex]];	
	If[
		StringContainsQ[shape, "polytope_3_3_"],
		activeLayerMin = 1; activeLayerMax = 15,
		activeLayerMin = 1; activeLayerMax = 9
	];
	If[shape == "polytope_3_4_3", activeLayerMax = 5];
	If[shape == "bitruncated_3_4_3", activeLayerMax = 7];
    
	exportAnimation[shape];
];
 *)

shape = shapes[[1]];

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

epsilon = 0.00000001;
ApproxSamePoint[point1_, point2_] := Round[point1, epsilon] == Round[point2, epsilon];

adjacentCells[c1_,c2_] := Length[Intersection[c1, c2, SameTest -> sameCenter]] == 1;
adjacentCellsIndex[cells_, id1_, id2_] := adjacentCells[cells[[id1]], cells[[id2]]];

sameCenter[set1_, set2_] := ApproxSamePoint[Total[set1], Total[set2]];

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

getRotationSchedule[cells_] := Module[
	{limit, adjMatrix, id1, graph, spanningTree, tree, rootCellCenter, rotationSchedule},
	limit = Length[cells];
	adjMatrix = {};

	For[id1 = 1, id1 <= limit, id1++,
		row = Table[If[adjacentCellsIndex[cells, id1, id2], 1, 0], 
			{id2, 1, limit}];
		Print[id1];
		AppendTo[adjMatrix, row];
	];

	Print[adjMatrix];

	graph = AdjacencyGraph[Range[Length[adjMatrix]], adjMatrix ];
	spanningTree = FindSpanningTree[DirectedGraph[graph]];
	tree = GraphTree[spanningTree];

	rootCellId = TreeData[tree];

	rotationSchedule = {};

	rotationSchedule = buildSchedule[tree, rotationSchedule, 1];
	rotationSchedule
];

randomRotationSchedule = {{1,8,1,{24,50,56,57,58,101,69,11,23,26,64,67,103,9,114,68,18,43,7,20,91,47,21,42,6,104,48,25,110,8}},{8,9,2,{24,50,56,57,58,101,69,11,23,26,64,67,103,9}},{9,11,3,{24,50,56,57,58,101,69,11}},{11,24,4,{24}},{11,50,4,{50}},{11,56,4,{56}},{11,57,4,{57}},{11,58,4,{58}},{11,69,4,{101,69}},{69,101,5,{101}},{9,23,3,{23}},{9,26,3,{26}},{9,64,3,{64}},{9,67,3,{67}},{9,103,3,{103}},{8,18,2,{114,68,18}},{18,68,3,{114,68}},{68,114,4,{114}},{8,20,2,{43,7,20}},{20,7,3,{43,7}},{7,43,4,{43}},{8,21,2,{91,47,21}},{21,47,3,{91,47}},{47,91,4,{91}},{8,104,2,{42,6,104}},{104,6,3,{42,6}},{6,42,4,{42}},{8,110,2,{48,25,110}},{110,25,3,{48,25}},{25,48,4,{48}},{1,12,1,{66,15,31,84,60,3,46,111,13,33,116,38,16,78,81,112,27,99,85,28,95,83,51,12}},{12,3,2,{66,15,31,84,60,3}},{3,15,3,{66,15}},{15,66,4,{66}},{3,31,3,{31}},{3,60,3,{84,60}},{60,84,4,{84}},{12,13,2,{46,111,13}},{13,111,3,{46,111}},{111,46,4,{46}},{12,16,2,{33,116,38,16}},{16,33,3,{33}},{16,38,3,{116,38}},{38,116,4,{116}},{12,27,2,{78,81,112,27}},{27,78,3,{78}},{27,112,3,{81,112}},{112,81,4,{81}},{12,28,2,{99,85,28}},{28,85,3,{99,85}},{85,99,4,{99}},{12,51,2,{95,83,51}},{51,83,3,{95,83}},{83,95,4,{95}},{1,14,1,{94,40,4,49,22,17,14}},{14,4,2,{94,40,4}},{4,40,3,{94,40}},{40,94,4,{94}},{14,17,2,{49,22,17}},{17,22,3,{49,22}},{22,49,4,{49}},{1,19,1,{74,45,73,36,93,37,107,88,39,19}},{19,36,2,{74,45,73,36}},{36,45,3,{74,45}},{45,74,4,{74}},{36,73,3,{73}},{19,37,2,{93,37}},{37,93,3,{93}},{19,39,2,{107,88,39}},{39,88,3,{107,88}},{88,107,4,{107}},{1,29,1,{120,118,70,86,106,71,105,82,119,100,87,29}},{29,70,2,{120,118,70}},{70,118,3,{120,118}},{118,120,4,{120}},{29,71,2,{86,106,71}},{71,86,3,{86}},{71,106,3,{106}},{29,82,2,{105,82}},{82,105,3,{105}},{29,87,2,{119,100,87}},{87,100,3,{119,100}},{100,119,4,{119}},{1,52,1,{117,41,5,89,79,115,30,80,34,76,52}},{52,5,2,{117,41,5}},{5,41,3,{117,41}},{41,117,4,{117}},{52,30,2,{89,79,115,30}},{30,79,3,{89,79}},{79,89,4,{89}},{30,115,3,{115}},{52,34,2,{80,34}},{34,80,3,{80}},{52,76,2,{76}},{1,53,1,{90,72,32,53}},{53,32,2,{90,72,32}},{32,72,3,{90,72}},{72,90,4,{90}},{1,54,1,{62,108,109,113,54}},{54,62,2,{62}},{54,113,2,{108,109,113}},{113,109,3,{108,109}},{109,108,4,{108}},{1,59,1,{97,96,98,59}},{59,98,2,{97,96,98}},{98,96,3,{97,96}},{96,97,4,{97}},{1,61,1,{77,44,35,61}},{61,35,2,{77,44,35}},{35,44,3,{77,44}},{44,77,4,{77}},{1,65,1,{92,75,63,65}},{65,63,2,{92,75,63}},{63,75,3,{92,75}},{75,92,4,{92}},{1,102,1,{55,10,2,102}},{102,2,2,{55,10,2}},{2,10,3,{55,10}},{10,55,4,{55}}};
rootCellId = 1;

manualRotationSchedule = {{41,31,1,{33,111,15,31}},{31,15,2,{33,111,15}},{15,111,3,{33,111}},{111,33,4,{33}},{41,80,1,{40,73,88,86,80}},{80,86,2,{40,73,88,86}},{86,88,3,{40,73,88}},{88,73,4,{40,73}},{73,40,5,{40}},{41,5,1,{43,22,25,2,94,100,106,113,34,99,118,82,54,61,90,49,24,103,8,9,104,5}},{5,2,2,{43,22,25,2}},{2,25,3,{43,22,25}},{25,22,4,{43,22}},{22,43,5,{43}},{5,34,2,{94,100,106,113,34}},{34,113,3,{94,100,106,113}},{113,106,4,{94,100,106}},{106,100,5,{94,100}},{100,94,6,{94}},{5,104,2,{99,118,82,54,61,90,49,24,103,8,9,104}},{104,61,3,{99,118,82,54,61}},{61,54,4,{99,118,82,54}},{54,82,5,{99,118,82}},{82,118,6,{99,118}},{118,99,7,{99}},{104,103,3,{90,49,24,103}},{103,24,4,{90,49,24}},{24,49,5,{90,49}},{49,90,6,{90}},{104,8,3,{8}},{104,9,3,{9}},{41,6,1,{72,46,48,10,93,87,71,62,35,85,116,81,55,70,29,65,18,67,11,69,56,6}},{6,10,2,{72,46,48,10}},{10,48,3,{72,46,48}},{48,46,4,{72,46}},{46,72,5,{72}},{6,35,2,{93,87,71,62,35}},{35,62,3,{93,87,71,62}},{62,71,4,{93,87,71}},{71,87,5,{93,87}},{87,93,6,{93}},{6,56,2,{85,116,81,55,70,29,65,18,67,11,69,56}},{56,55,3,{85,116,81,55}},{55,81,4,{85,116,81}},{81,116,5,{85,116}},{116,85,6,{85}},{56,67,3,{70,29,65,18,67}},{67,18,4,{70,29,65,18}},{18,65,5,{70,29,65}},{65,29,6,{70,29}},{29,70,7,{70}},{56,11,3,{11}},{56,69,3,{69}},{41,42,1,{37,39,63,68,44,32,38,112,66,19,21,64,58,77,53,28,78,84,101,97,89,42}},{42,44,2,{37,39,63,68,44}},{44,68,3,{37,39,63,68}},{68,63,4,{37,39,63}},{63,39,5,{37,39}},{39,37,6,{37}},{42,66,2,{32,38,112,66}},{66,112,3,{32,38,112}},{112,38,4,{32,38}},{38,32,5,{32}},{42,89,2,{19,21,64,58,77,53,28,78,84,101,97,89}},{89,77,3,{19,21,64,58,77}},{77,58,4,{19,21,64,58}},{58,64,5,{19,21,64}},{64,21,6,{19,21}},{21,19,7,{19}},{89,84,3,{53,28,78,84}},{84,78,4,{53,28,78}},{78,28,5,{53,28}},{28,53,6,{53}},{89,101,3,{101}},{89,97,3,{97}},{41,79,1,{4,16,27,60,36,47,75,114,117,20,14,12,51,23,50,92,108,95,98,96,83,79}},{79,60,2,{4,16,27,60}},{60,27,3,{4,16,27}},{27,16,4,{4,16}},{16,4,5,{4}},{79,117,2,{36,47,75,114,117}},{117,114,3,{36,47,75,114}},{114,75,4,{36,47,75}},{75,47,5,{36,47}},{47,36,6,{36}},{79,83,2,{20,14,12,51,23,50,92,108,95,98,96,83}},{83,51,3,{20,14,12,51}},{51,12,4,{20,14,12}},{12,14,5,{20,14}},{14,20,6,{20}},{83,95,3,{23,50,92,108,95}},{95,108,4,{23,50,92,108}},{108,92,5,{23,50,92}},{92,50,6,{23,50}},{50,23,7,{23}},{83,98,3,{98}},{83,96,3,{96}},{41,30,1,{7,17,13,3,45,91,107,109,115,74,119,120,105,76,57,26,110,102,1,59,52,30}},{30,3,2,{7,17,13,3}},{3,13,3,{7,17,13}},{13,17,4,{7,17}},{17,7,5,{7}},{30,115,2,{45,91,107,109,115}},{115,109,3,{45,91,107,109}},{109,107,4,{45,91,107}},{107,91,5,{45,91}},{91,45,6,{45}},{30,52,2,{74,119,120,105,76,57,26,110,102,1,59,52}},{52,76,3,{74,119,120,105,76}},{76,105,4,{74,119,120,105}},{105,120,5,{74,119,120}},{120,119,6,{74,119}},{119,74,7,{74}},{52,102,3,{57,26,110,102}},{102,110,4,{57,26,110}},{110,26,5,{57,26}},{26,57,6,{57}},{52,1,3,{1}},{52,59,3,{59}}};

manualRotationSchedule2 = {{41,31,1,{33,111,15,31}},{31,15,2,{33,111,15}},{15,111,3,{33,111}},{111,33,4,{33}},{41,80,1,{40,73,88,86,80}},{80,86,2,{40,73,88,86}},{86,88,3,{40,73,88}},{88,73,4,{40,73}},{73,40,5,{40}},{41,5,1,{43,22,25,2,94,100,106,113,34,99,118,82,54,61,90,49,24,103,104,5}},{5,2,2,{43,22,25,2}},{2,25,3,{43,22,25}},{25,22,4,{43,22}},{22,43,5,{43}},{5,34,2,{94,100,106,113,34}},{34,113,3,{94,100,106,113}},{113,106,4,{94,100,106}},{106,100,5,{94,100}},{100,94,6,{94}},{5,104,2,{99,118,82,54,61,90,49,24,103,104}},{104,61,3,{99,118,82,54,61}},{61,54,4,{99,118,82,54}},{54,82,5,{99,118,82}},{82,118,6,{99,118}},{118,99,7,{99}},{104,103,3,{90,49,24,103}},{103,24,4,{90,49,24}},{24,49,5,{90,49}},{49,90,6,{90}},{41,6,1,{72,46,48,10,93,87,71,62,35,85,116,81,55,70,29,65,18,67,56,6}},{6,10,2,{72,46,48,10}},{10,48,3,{72,46,48}},{48,46,4,{72,46}},{46,72,5,{72}},{6,35,2,{93,87,71,62,35}},{35,62,3,{93,87,71,62}},{62,71,4,{93,87,71}},{71,87,5,{93,87}},{87,93,6,{93}},{6,56,2,{85,116,81,55,70,29,65,18,67,56}},{56,55,3,{85,116,81,55}},{55,81,4,{85,116,81}},{81,116,5,{85,116}},{116,85,6,{85}},{56,67,3,{70,29,65,18,67}},{67,18,4,{70,29,65,18}},{18,65,5,{70,29,65}},{65,29,6,{70,29}},{29,70,7,{70}},{41,42,1,{37,39,63,68,44,32,38,112,66,19,21,64,58,77,53,28,78,84,89,42}},{42,44,2,{37,39,63,68,44}},{44,68,3,{37,39,63,68}},{68,63,4,{37,39,63}},{63,39,5,{37,39}},{39,37,6,{37}},{42,66,2,{32,38,112,66}},{66,112,3,{32,38,112}},{112,38,4,{32,38}},{38,32,5,{32}},{42,89,2,{19,21,64,58,77,53,28,78,84,89}},{89,77,3,{19,21,64,58,77}},{77,58,4,{19,21,64,58}},{58,64,5,{19,21,64}},{64,21,6,{19,21}},{21,19,7,{19}},{89,84,3,{53,28,78,84}},{84,78,4,{53,28,78}},{78,28,5,{53,28}},{28,53,6,{53}},{41,79,1,{4,16,27,60,36,47,75,114,117,20,14,12,51,23,50,92,108,95,83,79}},{79,60,2,{4,16,27,60}},{60,27,3,{4,16,27}},{27,16,4,{4,16}},{16,4,5,{4}},{79,117,2,{36,47,75,114,117}},{117,114,3,{36,47,75,114}},{114,75,4,{36,47,75}},{75,47,5,{36,47}},{47,36,6,{36}},{79,83,2,{20,14,12,51,23,50,92,108,95,83}},{83,51,3,{20,14,12,51}},{51,12,4,{20,14,12}},{12,14,5,{20,14}},{14,20,6,{20}},{83,95,3,{23,50,92,108,95}},{95,108,4,{23,50,92,108}},{108,92,5,{23,50,92}},{92,50,6,{23,50}},{50,23,7,{23}},{41,30,1,{7,17,13,3,45,91,107,109,115,74,119,120,105,76,57,26,110,102,11,9,8,1,69,101,97,96,98,59,52,30}},{30,3,2,{7,17,13,3}},{3,13,3,{7,17,13}},{13,17,4,{7,17}},{17,7,5,{7}},{30,115,2,{45,91,107,109,115}},{115,109,3,{45,91,107,109}},{109,107,4,{45,91,107}},{107,91,5,{45,91}},{91,45,6,{45}},{30,52,2,{74,119,120,105,76,57,26,110,102,11,9,8,1,69,101,97,96,98,59,52}},{52,76,3,{74,119,120,105,76}},{76,105,4,{74,119,120,105}},{105,120,5,{74,119,120}},{120,119,6,{74,119}},{119,74,7,{74}},{52,102,3,{57,26,110,102}},{102,110,4,{57,26,110}},{110,26,5,{57,26}},{26,57,6,{57}},{52,59,3,{11,9,8,1,69,101,97,96,98,59}},{59,1,4,{11,9,8,1}},{1,8,5,{11,9,8}},{8,9,6,{11,9}},{9,11,7,{11}},{59,98,4,{69,101,97,96,98}},{98,96,5,{69,101,97,96}},{96,97,6,{69,101,97}},{97,101,7,{69,101}},{101,69,8,{69}}};



rootCellId = 41;
(* rotationSchedule = randomRotationSchedule; *)
(* rotationSchedule = manualRotationSchedule; *)
rotationSchedule = manualRotationSchedule2;

rotation3D = IdentityMatrix[3];
(* for 600 cell, the following will lead to 60 rings. Each ring has 10 cells *)
If[shape == "polytope_5_3_3_cell120" || shape == "polytope_3_3_5_cell600", rotation3D = RotationMatrix[-ArcTan[1/phi], {0, 1, 0}]];
If[shape == "polytope_3_4_3" || shape == "bitruncated_3_4_3", rotation3D = RotationMatrix[Pi/6, {0, 0, 1}].RotationMatrix[-ArcTan[Sqrt[2]], {1, 0, 0}].RotationMatrix[Pi/4, {0, 0, 1}]];

fullProjectionMatrix = ArrayFlatten[
	{{rotation3D, 0}, {0, 1}}
];

(* fullProjectionMatrix = RotationMatrix[{rootCellCenter, {0, 0, 0, 1}}]; *)
(* If[shape == "polytope_3_3_5_cell600", fullProjectionMatrix = ArrayFlatten[{{1, 0, 0}, {0, RotationMatrix[-ArcTan[Sqrt[2]]], 0}, {0, 0, 1}}].ArrayFlatten[{{IdentityMatrix[2], 0}, {0, RotationMatrix[Pi/4]}}] ]; *)

cells = Map[#.Transpose[fullProjectionMatrix] &, cells, {2}];
cellCenters = Map[getCellCenter, cells];
cellColors = Map[getHue[mapHopfFibration[#]]&, cellCenters];

(* rootCellCenter = getCellCenter[cells[[rootCellId]]]; *)
(* Print[rootCellCenter//N]; *)
(* Exit[]; *)

maxLevel = Max[Map[#[[3]]&, rotationSchedule ]];
(* Print[maxLevel]; *)

foldCells[cells_, rotationSchedule_, foldPercents_] := Module[
	{originalDihedralAngle, rotatedCells, scheduleId, level, schedule, cell1Id, cell2Id, rotatedCellIds},
	originalDihedralAngle = 0;
	rotatedCells = cells;

	For[scheduleId = 1, scheduleId <= Length[rotationSchedule], scheduleId++,
		(* Print["scheduleId " <> IntegerString[scheduleId] <> " out of " <> IntegerString[Length[rotationSchedule]]]; *)
		schedule = rotationSchedule[[scheduleId]];
		level = schedule[[3]];
		If[level >= 1,
			cell1Id = schedule[[1]];
			cell2Id = schedule[[2]];
			rotatedCellIds = schedule[[4]];
			cell1 = rotatedCells[[cell1Id]];
			cell2 = rotatedCells[[cell2Id]];
			pivot = Intersection[cell1, cell2, SameTest -> sameCenter];
			If[Length[pivot] != 1,
				Print["Unexpected error. Cannot find correct pivot"];
				Print[schedule];
				Print[pivot];
				Exit[];
			];

			cellCenter1 = getCellCenter[cell1];
			cellCenter2 = getCellCenter[cell2];
			pivotCenter = Mean[pivot[[1]] ];
			relativeCell1 = cellCenter1 - pivotCenter;
			relativeCell2 = cellCenter2 - pivotCenter;
			
			originalDihedralAngle = ArcCos[ Dot[relativeCell1//N, relativeCell2]/Norm[relativeCell1//N]/Norm[relativeCell2//N] ];
			(* Print[originalDihedralAngle / Pi * 180.]; *)
			grand120CellDihedralAngle = 72/180 * Pi;
			angleToFlat = Pi - originalDihedralAngle;
			angleToStellate = grand120CellDihedralAngle - originalDihedralAngle;
			perc = foldPercents[[level]];
			angleToTarget = If[perc >= 0, angleToFlat, angleToStellate];
			rotMatrix = RotationMatrix[angleToTarget * Abs[perc], {relativeCell2, relativeCell1}];
			For[cid = 1, cid <= Length[rotatedCellIds], cid++,
				cellId = rotatedCellIds[[cid]];
				rotatedCell = rotatedCells[[cellId]];
				rotatedCell = Map[((# - pivotCenter).rotMatrix + pivotCenter)&, rotatedCell, {2}];
				rotatedCells[[cellId]] = rotatedCell;
			];
		];
	];

	allCenters = Map[getCellCenter, rotatedCells];
	selectedCenters = allCenters[[highlightedCellIds]];

	centerAfterFolding = Mean[allCenters[[fixedCells]]];
	shiftedCenters = Map[# - centerAfterFolding &, allCenters];
	shiftedSelectedCenters = shiftedCenters[[highlightedCellIds]];

	layerGroupByAfterFolding = 
	 GroupBy[Range[Length[shiftedSelectedCenters]], 
	  Round[normalized[shiftedSelectedCenters[[#]]][[4]], epsilon] &];
	(* Print["after folding, w-coordinates by layer"]; *)
	(* Print[Sort[Keys[layerGroupByAfterFolding]]]; *)

	layersAfterFolding = Map[If[KeyExistsQ[layerGroupByAfterFolding,#],layerGroupByAfterFolding[#], {}]&, originalDepths];
	layerLengths = Length/@layersAfterFolding;
	(* Print[layerLengths]; *)

	shiftedOtherCenters = shiftedCenters[[otherCells]];
	otherLayerGroupByAfterFolding = 
	 GroupBy[Range[Length[shiftedOtherCenters]], 
	  Round[normalized[shiftedOtherCenters[[#]]][[4]], epsilon] &];

	otherLayersAfterFolding = Map[If[KeyExistsQ[otherLayerGroupByAfterFolding,#],otherLayerGroupByAfterFolding[#], {}]&, originalDepths];
	otherLayerLengths = Length/@otherLayersAfterFolding;
	(* Print[otherLayersAfterFolding]; *)
	Print[otherLayerLengths];
	
	If[KeyExistsQ[layerHistogramMap, otherLayerLengths],
		AppendTo[ layerHistogramMap[otherLayerLengths], candidateId],
		layerHistogramMap[otherLayerLengths] = {candidateId}
	];
	Print[layerHistogramMap];

(* 	If[Length[focusedLayers] == Length[layersAfterFolding],
		Print["layer counts match before and after folding"],
		Print["layer counts do not match before and after folding. Before vs after:"];
		Print[{Length[focusedLayers], Length[layersAfterFolding]}];
	]; *)

	forceQuit = False;
	(* forceQuit = True; *)

	uniqueCenters = Union[selectedCenters, SameTest -> ApproxSamePoint];
	If[Length[uniqueCenters] == Length[highlightedCellIds] || forceQuit,
		Print["Found a good net matching cell count"];
		Print["Element counts: cells, faces, edges, vertices:"];
		Print[Map[Length, {uniqueCenters, activeFaces, activeEdges, activeVertices}]];
		(* Print[rotationSchedule]; *)
		(* Print[FromCharacterCode[{7, 7, 7}]]; *)
		(* Exit[]; *)

(* 		activeFaces = Union[ Flatten[rotatedCells[[highlightedCellIds]], 1], SameTest -> sameCenter ];
		If[Length[activeFaces] == 720 || forceQuit,
			activeEdges = Union[ Flatten[Map[getEdgesFromFace, activeFaces], 1], SameTest -> sameCenter];
			If[Length[activeEdges] == 720 || forceQuit,
				activeVertices = Union[ Flatten[activeFaces,1], SameTest -> ApproxSamePoint];
				If[Length[activeVertices] == 120 || forceQuit,
					Print["Found a good net"];
					Print["Element counts: cells, faces, edges, vertices:"];
					Print[Map[Length, {uniqueCenters, activeFaces, activeEdges, activeVertices}]];
					Print[rotationSchedule];
					Exit[];
				];
			];
		]; *)
	];

	If[Length[uniqueCenters] > maxCellCount,
		maxCellCount = Length[uniqueCenters];
		maxCellId = {candidateId},
		If[Length[uniqueCenters] == maxCellCount,
			AppendTo[maxCellId, candidateId];
		];
	];

(* 	If[Length[activeFaces] > maxFaceCount,
		maxFaceCount = Length[activeFaces];
		maxFaceId = {candidateId},
		If[Length[activeFaces] == maxFaceCount,
			AppendTo[maxFaceId, candidateId];
		];
	];

	If[Length[activeEdges] > maxEdgeCount,
		maxEdgeCount = Length[activeEdges];
		maxEdgeId = {candidateId},
		If[Length[activeEdges] == maxEdgeCount,
			AppendTo[maxEdgeId, candidateId];
		];		
	]; *)

	Print["Found a bad net"];
	(* Print["Element counts: cells, faces, edges, vertices:"]; *)
	(* Print[Map[Length, {uniqueCenters, activeFaces, activeEdges, activeVertices}]]; *)
	(* Print[{maxCellCount, maxFaceCount, maxEdgeCount, maxCellId, maxFaceId, maxEdgeId}]; *)
	Print[Length[uniqueCenters]];
	Print[{maxCellCount, maxCellId}];	
	(* Print[rotationSchedule]; *)

	

	(* negative fold, random tree {120, 629, 707, 119} *)
	(* negative fold, manual tree {120, 530, 690, 120} *)
	(* negative fold, manual tree2 {120, 544, 696, 120} *)
	(* ideal case: {120, 720, 720, 120} *)
	rotatedCells
];

orientedCellCenters = cellCenters;
orientedCellCentersMap = <||>;
For[cid = 1, cid <= Length[cellCenters], cid++,
  cellCenter = cellCenters[[cid]];
  orientedCellCentersMap[Round[cellCenter, epsilon]] = cid;
  ];

layerGroupBy = 
 GroupBy[Range[Length[orientedCellCenters]], 
  Round[normalized[orientedCellCenters[[#]]][[4]], epsilon] &];
Print["before folding, w-coordinates by layer"];
originalDepths = Sort[Keys[layerGroupBy]];
Print[originalDepths];
layers = Map[If[KeyExistsQ[layerGroupBy,#],layerGroupBy[#], {}]&, originalDepths];
Print[Map[Length, layers]];

layerMap = <||>;

For[layerId = 1, layerId <= Length[layers], layerId++,
  layer = layers[[layerId]];
  For[cid = 1, cid <= Length[layer], cid++,
  	cell = layer[[cid]];
  	layerMap[cell] = layerId;
  ];
];

rotatedCids = 
  Table[orientedCellCentersMap[
    Round[orientedCellCenters[[cid]].RotationMatrix[k 2 Pi/5, {{1, 0, 0, 0}, {0, 1, 0, 0}}], 
     epsilon]], {cid, 1, 120}, {k, 0, 4}];

rotatedCids = Map[Union[Sort[#]]&, rotatedCids];
rotationOrbits = Map[#[[1]] &, Tally[rotatedCids]];

rotationOrbitMap = <||>;
For[orbitId = 1, orbitId <= Length[rotationOrbits], orbitId++,
  orbit = rotationOrbits[[orbitId]];
  For[cid = 1, cid <= Length[orbit], cid++,
  	cell = orbit[[cid]];
  	(* rotationOrbitMap[cell] = rotationOrbits[[orbitId]]; *)
  	rotationOrbitMap[cell] = orbitId;
  ];
];


fixedLayers = { 1, 2, 4, 6, 8, 9 };
fixedCells = Apply[Join, layers[[ fixedLayers ]]];
(* otherLayers = {3, 5, 7}; *)
(* otherLayers = {3}; *)
(* otherLayers = {7}; *)
otherLayers = {5};
otherCells = Apply[Join, layers[[otherLayers]]];

focusedLayers = Join[fixedLayers, otherLayers];

fixedEdges = {};
For[layerId = 2, layerId <= Length[fixedLayers], layerId++,
	layer = fixedLayers[[layerId]];
	innerLayer = fixedLayers[[layerId - 1]];

	For[cellId = 1, cellId <= Length[layers[[layer]]], cellId++,
		fromCell = layers[[layer]][[cellId]];
		For[cellId2 = 1, cellId2 <= Length[layers[[innerLayer]]], cellId2++,
			toCell = layers[[innerLayer]][[cellId2]];
			If[adjacentCellsIndex[cells, fromCell, toCell],
				If[ layer == 9 && (orientedCellCenters[[toCell]][[3]] < 0 || Norm[orientedCellCenters[[toCell]][[{1, 2}]] ] > epsilon),
						Continue[],
					AppendTo[fixedEdges, fromCell \[UndirectedEdge] toCell];
					Break[]
				];
			];
		];
	];
];

edgesPrototype = {};

For[layerId = 1, layerId <= Length[otherLayers], layerId++,
	otherLayer = otherLayers[[layerId]];
	fromCells = layers[[otherLayer]];
	orbitsInLayer = Union[Map[rotationOrbitMap, fromCells]];
	For[oid = 1, oid <= Length[orbitsInLayer] && oid<=200, oid++,
		orbitId = orbitsInLayer[[oid]];
		cellsInOrbit = rotationOrbits[[orbitId]];
		sampleCell = cellsInOrbit[[1]];
		neighborCells = Select[Range[Length[cells]], adjacentCellsIndex[cells, sampleCell, #] == True &];
		For[ncid = 1, ncid <= Length[neighborCells], ncid++,
			neighborCell = neighborCells[[ncid]];
			If[MemberQ[focusedLayers, layerMap[neighborCell] ],
				AppendTo[edgesPrototype, sampleCell \[UndirectedEdge] neighborCell];
			];
		];
	];
];

(* Print[edgesPrototype//Length]; *)

getEdgeGroupFromEdge[edge_] := Module[
	{edgeGroup},
	edgeGroup = Table[
		orientedCellCentersMap[
	    	Round[orientedCellCenters[[edge[[1]]]].RotationMatrix[k 2 Pi/5, {{1, 0, 0, 0}, {0, 1, 0, 0}}], 
     		epsilon]] \[UndirectedEdge] 
     	orientedCellCentersMap[
	    	Round[orientedCellCenters[[edge[[2]]]].RotationMatrix[k 2 Pi/5, {{1, 0, 0, 0}, {0, 1, 0, 0}}], 
     		epsilon]], {k, 0, 4}];
     edgeGroup = Map[If[ #[[1]] < #[[2]], #, #[[2]] \[UndirectedEdge] #[[1]] ]&, edgeGroup];
     Sort[edgeGroup]
];

uniqueEdgesUpToRotation = Map[#[[1]]&, Tally[edgesPrototype, getEdgeGroupFromEdge[#1] == getEdgeGroupFromEdge[#2]& ]];

allEdgesByGroup = Map[getEdgeGroupFromEdge, uniqueEdgesUpToRotation];

Print[Length[allEdgesByGroup]];
(* topN = 121; *)
(* topN = 10; *)
(* topN = 10000; *)
topN = 10 * 1000 * 1000;
(* topN = 705432; *)
(* treeCandidates = 
  Select[TreeGraphQ[Graph@#] &]@
   Select[VertexCount@# == VertexCount[subgraph] &]@
    Subsets[EdgeList[subgraph], {VertexCount[subgraph] - 1}, topN];
 *)

Print["treeCandidates full count: " <> IntegerString[Binomial[Length[allEdgesByGroup], Length[otherCells]/5]]];

treeCandidates = Subsets[allEdgesByGroup, {Length[otherCells]/5}, topN];

(* treeCandidates = {edges}; *)
(* treeCandidates = Map[{#}&, crossBundleEdges]; *)
(* treeCandidates = {}; *)

Print["Found trees as candidates: " <> IntegerString[Length[treeCandidates]]];
If[Length[treeCandidates] == 0,
	treeCandidates = { {} };
];

maxCellCount = -1;
maxFaceCount = -1;
maxEdgeCount = -1;
maxCellId = {};
maxFaceId = {};
maxEdgeId = {};
layerHistogramMap = <||>;

histogramMapLayer3 = <|{0, 0, 0, 0, 15, 0, 5, 0, 0} -> {11528, 11531, 11534, 11595, 11605, 11608, 11798, 11801, 11804, 11853, 11856, 11859, 11868, 11871, 11928, 11931, 11934, 11973, 11976, 12017, 12057, 12060, 15167, 15170, 15173, 15197, 15200, 15203, 15212, 15215, 15852, 15855, 15858, 15919, 15929, 15932, 15973, 15976, 15979, 15988, 15991, 15994, 16025, 16055, 16065, 16068, 16122, 16125, 16128, 16177, 16180, 16183, 16192, 16195, 16252, 16255, 16258, 16297, 16300, 16341, 16381, 16384, 16938, 16941, 16944, 16968, 16971, 16974, 16983, 16986, 17623, 17626, 17629, 17690, 17700, 17703, 17744, 17747, 17750, 17759, 17762, 17765, 17796, 17826, 17836, 17839, 17893, 17896, 17899, 17948, 17951, 17954, 17963, 17966, 18023, 18026, 18029, 18068, 18071, 18112, 18152, 18155, 19232, 19235, 19238, 19247, 19250, 19654, 19657, 19660, 19699, 19702}, {0, 0, 0, 0, 20, 0, 0, 0, 0} -> {11597, 11600, 11603, 11612, 11615, 12019, 12022, 12025, 12064, 12067, 15921, 15924, 15927, 15936, 15939, 16027, 16030, 16033, 16057, 16060, 16063, 16072, 16075, 16343, 16346, 16349, 16388, 16391, 17692, 17695, 17698, 17707, 17710, 17798, 17801, 17804, 17828, 17831, 17834, 17843, 17846, 18114, 18117, 18120, 18159, 18162}, {0, 0, 0, 0, 10, 0, 10, 0, 0} -> {11851, 11864, 11926, 11966, 15128, 15131, 15134, 15205, 15208, 16175, 16188, 16250, 16290, 16884, 16887, 16890, 16976, 16979, 17946, 17959, 18021, 18061, 19163, 19166, 19169, 19230, 19433, 19436, 19439, 19652}|>;

histogramMapLayer7 = <|{0, 0, 5, 0, 15, 0, 0, 0, 0} -> {4963, 4964, 5000, 5001, 5006, 5017, 5018, 5023, 5613, 5614, 5706, 5707, 5802, 5803, 5808, 5910, 5911, 5916, 5919, 5920, 5925, 6014, 6015, 6149, 6150, 6166, 6167, 6172, 6515, 6516, 6524, 6525, 6532, 6533, 6602, 6603, 6608, 6610, 6611, 6616, 10488, 10489, 10525, 10526, 10531, 10542, 10543, 10548, 11138, 11139, 11231, 11232, 11327, 11328, 11333, 11435, 11436, 11441, 11444, 11445, 11450, 11539, 11540, 11674, 11675, 11691, 11692, 11697, 12040, 12041, 12049, 12050, 12057, 12058, 12127, 12128, 12133, 12135, 12136, 12141, 17359, 17360, 17376, 17377, 17700, 17701, 17706, 17819, 17820, 17825, 18773, 18774, 18866, 18867, 18962, 18963, 18968, 19070, 19071, 19076, 19175, 19309, 19326, 19327, 19332, 19675, 19676, 19692, 19693, 19770, 19771, 19776}, {0, 0, 10, 0, 10, 0, 0, 0, 0} -> {5062, 5063, 5075, 5076, 5081, 5794, 5864, 6146, 6483, 10507, 10508, 10513, 10587, 10588, 11319, 11389, 11671, 12008, 17530, 17531, 17536, 17635, 17769, 18230, 18231, 18236, 18954, 19024, 19306, 19643}, {0, 0, 0, 0, 20, 0, 0, 0, 0} -> {5739, 5740, 5748, 5749, 5756, 5757, 6072, 6073, 6078, 6080, 6081, 6086, 6199, 6200, 6205, 6208, 6209, 6214, 11264, 11265, 11273, 11274, 11281, 11282, 11597, 11598, 11603, 11605, 11606, 11611, 11724, 11725, 11730, 11733, 11734, 11739, 18899, 18900, 18916, 18917, 19240, 19241, 19246, 19359, 19360, 19365}|>;

candidateIdsLayer7 = {4963, 4964, 5000, 5001, 5006, 5017, 5018, 5023, 5062, 5063, 5075, 5076, 5081, 5613, 5614, 5706, 5707, 5739, 5740, 5748, 5749, 5756, 5757, 5794, 5802, 5803, 5808, 5864, 5910, 5911, 5916, 5919, 5920, 5925, 6014, 6015, 6072, 6073, 6078, 6080, 6081, 6086, 6146, 6149, 6150, 6166, 6167, 6172, 6199, 6200, 6205, 6208, 6209, 6214, 6483, 6515, 6516, 6524, 6525, 6532, 6533, 6602, 6603, 6608, 6610, 6611, 6616, 10488, 10489, 10507, 10508, 10513, 10525, 10526, 10531, 10542, 10543, 10548, 10587, 10588, 11138, 11139, 11231, 11232, 11264, 11265, 11273, 11274, 11281, 11282, 11319, 11327, 11328, 11333, 11389, 11435, 11436, 11441, 11444, 11445, 11450, 11539, 11540, 11597, 11598, 11603, 11605, 11606, 11611, 11671, 11674, 11675, 11691, 11692, 11697, 11724, 11725, 11730, 11733, 11734, 11739, 12008, 12040, 12041, 12049, 12050, 12057, 12058, 12127, 12128, 12133, 12135, 12136, 12141, 17359, 17360, 17376, 17377, 17530, 17531, 17536, 17635, 17700, 17701, 17706, 17769, 17819, 17820, 17825, 18230, 18231, 18236, 18773, 18774, 18866, 18867, 18899, 18900, 18916, 18917, 18954, 18962, 18963, 18968, 19024, 19070, 19071, 19076, 19175, 19240, 19241, 19246, 19306, 19309, 19326, 19327, 19332, 19359, 19360, 19365, 19643, 19675, 19676, 19692, 19693, 19770, 19771, 19776};

candidateIdsLayer3 = {11528, 11531, 11534, 11595, 11597, 11600, 11603, 11605, 11608, 11612, 11615, 11798, 11801, 11804, 11851, 11853, 11856, 11859, 11864, 11868, 11871, 11926, 11928, 11931, 11934, 11966, 11973, 11976, 12017, 12019, 12022, 12025, 12057, 12060, 12064, 12067, 15128, 15131, 15134, 15167, 15170, 15173, 15197, 15200, 15203, 15205, 15208, 15212, 15215, 15852, 15855, 15858, 15919, 15921, 15924, 15927, 15929, 15932, 15936, 15939, 15973, 15976, 15979, 15988, 15991, 15994, 16025, 16027, 16030, 16033, 16055, 16057, 16060, 16063, 16065, 16068, 16072, 16075, 16122, 16125, 16128, 16175, 16177, 16180, 16183, 16188, 16192, 16195, 16250, 16252, 16255, 16258, 16290, 16297, 16300, 16341, 16343, 16346, 16349, 16381, 16384, 16388, 16391, 16884, 16887, 16890, 16938, 16941, 16944, 16968, 16971, 16974, 16976, 16979, 16983, 16986, 17623, 17626, 17629, 17690, 17692, 17695, 17698, 17700, 17703, 17707, 17710, 17744, 17747, 17750, 17759, 17762, 17765, 17796, 17798, 17801, 17804, 17826, 17828, 17831, 17834, 17836, 17839, 17843, 17846, 17893, 17896, 17899, 17946, 17948, 17951, 17954, 17959, 17963, 17966, 18021, 18023, 18026, 18029, 18061, 18068, 18071, 18112, 18114, 18117, 18120, 18152, 18155, 18159, 18162, 19163, 19166, 19169, 19230, 19232, 19235, 19238, 19247, 19250, 19433, 19436, 19439, 19652, 19654, 19657, 19660, 19699, 19702};

histogramMapLayer5Partial = <||>;

candidateIdsLayer5Partial = {8212, 8214, 8216, 8217, 8291, 8292, 8296, 8297, 8316, 8317, 8319, 8321, 8322, 8327, 8328, 8330, 8332, 8333, 9408, 9409, 9410, 9411, 9414, 9415, 9421, 9422, 9434, 9435, 9436, 9437, 9438, 9439, 9440, 9441, 10005, 10006, 10014, 10015, 10019, 10020, 10026, 10027, 10040, 10041, 10044, 10045, 10148, 10149, 10150, 10151, 10157, 10158, 10159, 10160, 10163, 10164, 10170, 10171, 10183, 10184, 10185, 10186, 10187, 10188, 10189, 10190, 10203, 10206, 10212, 10215, 10218, 10219, 10225, 10226, 10238, 10241, 10242, 10245, 12706, 12709, 12711, 12712, 12772, 12773, 12775, 12777, 12778, 12786, 12787, 12789, 12791, 12792, 12822, 12823, 12827, 12828, 13894, 13895, 13896, 13897, 13909, 13910, 13916, 13917, 13929, 13930, 13931, 13932, 13933, 13934, 13935, 13936, 14408, 14409, 14410, 14411, 14417, 14418, 14419, 14420, 14423, 14424, 14430, 14431, 14443, 14444, 14445, 14446, 14447, 14448, 14449, 14450, 14500, 14501, 14509, 14510, 14514, 14515, 14521, 14522, 14535, 14536, 14539, 14540, 14698, 14701, 14707, 14710, 14713, 14714, 14720, 14721, 14733, 14736, 14737, 14740, 19844, 19845, 19846, 19849, 19850, 19910, 19911, 19912, 19915, 19916, 19924, 19925, 19926, 19929, 19930, 19960, 19961, 19965, 19966, 20144, 20145, 20146, 20149, 20150, 20224, 20225, 20229, 20230, 20249, 20250, 20251, 20254, 20255, 20260, 20261, 20262, 20265, 20266, 21694, 21695, 21708, 21709, 21733, 21734, 21744, 21745, 21830, 21831, 21844, 21845, 21869, 21870, 21880, 21881, 30409, 30410, 30411, 30412, 30418, 30419, 30420, 30421, 30424, 30425, 30431, 30432, 30444, 30445, 30446, 30447, 30448, 30449, 30450, 30451, 30923, 30924, 30925, 30926, 30932, 30933, 30934, 30935, 30938, 30939, 30945, 30946, 30958, 30959, 30960, 30961, 30962, 30963, 30964, 30965, 31015, 31016, 31024, 31025, 31029, 31030, 31036, 31037, 31050, 31051, 31054, 31055, 31213, 31216, 31222, 31225, 31228, 31229, 31235, 31236, 31248, 31251, 31252, 31255, 32709, 32710, 32711, 32712, 32718, 32719, 32720, 32721, 32724, 32725, 32731, 32732, 32744, 32745, 32746, 32747, 32748, 32749, 32750, 32751, 33315, 33316, 33324, 33325, 33329, 33330, 33336, 33337, 33350, 33351, 33354, 33355, 33458, 33459, 33460, 33461, 33467, 33468, 33469, 33470, 33473, 33474, 33480, 33481, 33493, 33494, 33495, 33496, 33497, 33498, 33499, 33500, 33513, 33516, 33522, 33525, 33528, 33529, 33535, 33536, 33548, 33551, 33552, 33555, 34680, 34681, 34682, 34683, 34685, 34686, 34716, 34717, 34718, 34719, 34721, 34722, 34820, 34822, 34824, 34834, 34836, 34838, 34859, 34861, 34863, 34870, 34872, 34874, 34955, 34958, 34961, 34969, 34972, 34975, 34994, 34997, 35000, 35005, 35008, 35011, 42103, 42104, 42110, 42111, 42302, 42303, 42309, 42310, 42813, 42814, 42815, 42816, 42822, 42823, 42824, 42825, 42832, 42833, 42837, 42838, 42848, 42849, 42850, 42851, 42905, 42906, 42914, 42915, 42923, 42929, 42940, 42941, 43048, 43049, 43050, 43051, 43057, 43058, 43059, 43060, 43067, 43068, 43072, 43073, 43083, 43084, 43085, 43086, 43103, 43106, 43112, 43115, 43123, 43127, 43138, 43141, 43493, 43494, 43495, 43496, 43502, 43503, 43504, 43505, 43512, 43513, 43517, 43518, 43532, 43533, 43534, 43535, 43585, 43586, 43594, 43595, 43603, 43609, 43624, 43625, 43728, 43729, 43730, 43731, 43737, 43738, 43739, 43740, 43747, 43748, 43752, 43753, 43767, 43768, 43769, 43770, 43783, 43786, 43792, 43795, 43803, 43807, 43822, 43825, 110870, 110871, 110873, 110875, 110876, 110989, 110990, 110994, 110995, 111014, 111015, 111017, 111019, 111020, 111025, 111026, 111028, 111030, 111031, 111137, 111138, 111140, 111142, 111154, 111155, 111157, 111160, 111309, 111310, 111312, 111314, 111389, 111390, 111394, 111414, 111415, 111417, 111419, 111425, 111426, 111428, 111430, 111531, 111532, 111534, 111537, 111713, 111714, 111718, 111738, 111739, 111741, 111743, 111749, 111750, 111752, 111754, 111849, 111850, 111855, 111874, 111875, 111877, 111880, 111885, 111886, 111888, 111891, 111969, 111970, 111975, 111994, 111995, 111997, 112000, 112005, 112006, 112008, 112011, 114563, 114564, 114565, 114566, 114572, 114573, 114574, 114575, 114578, 114579, 114585, 114586, 114598, 114599, 114600, 114601, 114602, 114603, 114604, 114605, 115530, 115531, 115539, 115540, 115544, 115545, 115551, 115552, 115565, 115566, 115569, 115570, 115673, 115674, 115675, 115676, 115682, 115683, 115684, 115685, 115688, 115689, 115695, 115696, 115708, 115709, 115710, 115711, 115712, 115713, 115714, 115715, 115728, 115731, 115737, 115740, 115743, 115744, 115750, 115751, 115763, 115766, 115767, 115770, 116407, 116408, 116409, 116410, 116416, 116417, 116418, 116419, 116422, 116429, 116442, 116443, 116444, 116445, 116543, 116544, 116545, 116546, 116552, 116553, 116554, 116555, 116559, 116566, 116582, 116583, 116584, 116585, 116860, 116861, 116869, 116870, 116874, 116875, 116881, 116882, 116895, 116896, 116899, 116900, 117058, 117061, 117067, 117070, 117073, 117074, 117080, 117081, 117093, 117096, 117097, 117100, 117394, 117395, 117396, 117397, 117403, 117404, 117405, 117406, 117409, 117416, 117429, 117430, 117431, 117432, 118000, 118001, 118009, 118010, 118014, 118021, 118035, 118036, 118143, 118144, 118145, 118146, 118152, 118153, 118154, 118155, 118158, 118165, 118178, 118179, 118180, 118181, 118198, 118201, 118207, 118210, 118213, 118220, 118233, 118236, 118772, 118773, 118774, 118775, 118781, 118782, 118783, 118784, 118788, 118795, 118811, 118812, 118813, 118814, 118969, 118970, 118978, 118979, 118983, 118984, 118990, 118991, 119004, 119005, 119008, 119009, 119167, 119170, 119176, 119179, 119182, 119183, 119189, 119190, 119202, 119205, 119206, 119209, 119785, 119786, 119794, 119795, 119799, 119806, 119820, 119821, 119928, 119929, 119930, 119931, 119937, 119938, 119939, 119940, 119943, 119950, 119963, 119964, 119965, 119966, 119983, 119986, 119992, 119995, 119998, 120005, 120018, 120021, 120465, 120466, 120474, 120475, 120480, 120487, 120504, 120505, 120608, 120609, 120610, 120611, 120617, 120618, 120619, 120620, 120624, 120631, 120647, 120648, 120649, 120650, 120663, 120666, 120672, 120675, 120679, 120686, 120702, 120705, 121025, 121026, 121034, 121035, 121040, 121047, 121064, 121065, 121168, 121169, 121170, 121171, 121177, 121178, 121179, 121180, 121184, 121191, 121207, 121208, 121209, 121210, 121223, 121226, 121232, 121235, 121239, 121246, 121262, 121265, 142335, 142336, 142338, 142340, 142341, 142440, 142441, 142443, 142445, 142446, 142454, 142455, 142457, 142459, 142460, 142490, 142491, 142495, 142496, 142602, 142603, 142605, 142607, 142619, 142620, 142622, 142625, 142774, 142775, 142777, 142779, 142840, 142841, 142843, 142845, 142854, 142855, 142857, 142859, 142890, 142891, 142895, 142996, 142997, 142999, 143002, 143164, 143165, 143167, 143169, 143178, 143179, 143181, 143183, 143214, 143215, 143219, 143300, 143301, 143303, 143306, 143314, 143315, 143317, 143320, 143350, 143351, 143356, 143420, 143421, 143423, 143426, 143434, 143435, 143437, 143440, 143470, 143471, 143476, 146028, 146029, 146030, 146031, 146037, 146038, 146039, 146040, 146043, 146044, 146050, 146051, 146063, 146064, 146065, 146066, 146067, 146068, 146069, 146070, 146903, 146904, 146905, 146906, 146912, 146913, 146914, 146915, 146918, 146919, 146925, 146926, 146938, 146939, 146940, 146941, 146942, 146943, 146944, 146945, 146995, 146996, 147004, 147005, 147009, 147010, 147016, 147017, 147030, 147031, 147034, 147035, 147193, 147196, 147202, 147205, 147208, 147209, 147215, 147216, 147228, 147231, 147232, 147235, 147872, 147873, 147874, 147875, 147881, 147882, 147883, 147884, 147887, 147894, 147907, 147908, 147909, 147910, 148008, 148009, 148010, 148011, 148017, 148018, 148019, 148020, 148024, 148031, 148047, 148048, 148049, 148050, 148325, 148326, 148334, 148335, 148339, 148340, 148346, 148347, 148360, 148361, 148364, 148365, 148523, 148526, 148532, 148535, 148538, 148539, 148545, 148546, 148558, 148561, 148562, 148565, 148859, 148860, 148861, 148862, 148868, 148869, 148870, 148871, 148874, 148881, 148894, 148895, 148896, 148897, 149373, 149374, 149375, 149376, 149382, 149383, 149384, 149385, 149388, 149395, 149408, 149409, 149410, 149411, 149465, 149466, 149474, 149475, 149479, 149486, 149500, 149501, 149663, 149666, 149672, 149675, 149678, 149685, 149698, 149701, 150237, 150238, 150239, 150240, 150246, 150247, 150248, 150249, 150253, 150260, 150276, 150277, 150278, 150279, 150434, 150435, 150443, 150444, 150448, 150449, 150455, 150456, 150469, 150470, 150473, 150474, 150632, 150635, 150641, 150644, 150647, 150648, 150654, 150655, 150667, 150670, 150671, 150674, 151158, 151159, 151160, 151161, 151167, 151168, 151169, 151170, 151173, 151180, 151193, 151194, 151195, 151196, 151250, 151251, 151259, 151260, 151264, 151271, 151285, 151286, 151448, 151451, 151457, 151460, 151463, 151470, 151483, 151486, 151838, 151839, 151840, 151841, 151847, 151848, 151849, 151850, 151854, 151861, 151877, 151878, 151879, 151880, 151930, 151931, 151939, 151940, 151945, 151952, 151969, 151970, 152128, 152131, 152137, 152140, 152144, 152151, 152167, 152170, 152398, 152399, 152400, 152401, 152407, 152408, 152409, 152410, 152414, 152421, 152437, 152438, 152439, 152440, 152490, 152491, 152499, 152500, 152505, 152512, 152529, 152530, 152688, 152691, 152697, 152700, 152704, 152711, 152727, 152730, 189167, 189169, 189172, 189173, 189272, 189273, 189274, 189277, 189278, 189286, 189287, 189288, 189291, 189292, 189322, 189323, 189327, 189328, 189434, 189435, 189436, 189439, 189451, 189452, 189453, 189457, 189606, 189607, 189608, 189611, 189672, 189673, 189674, 189677, 189686, 189687, 189688, 189691, 189722, 189723, 189727, 189828, 189829, 189830, 189834, 189996, 189997, 189998, 190001, 190010, 190011, 190012, 190015, 190046, 190047, 190051, 190132, 190133, 190134, 190138, 190146, 190147, 190148, 190152, 190182, 190183, 190188, 190252, 190253, 190254, 190258, 190266, 190267, 190268, 190272, 190302, 190303, 190308, 191468, 191469, 191472, 191473, 191586, 191587, 191591, 191592, 191611, 191612, 191613, 191616, 191617, 191622, 191623, 191624, 191627, 191628, 191734, 191735, 191736, 191739, 191751, 191752, 191753, 191757, 191906, 191907, 191908, 191911, 191986, 191987, 191991, 192011, 192012, 192013, 192016, 192022, 192023, 192024, 192027, 192128, 192129, 192130, 192134, 192310, 192311, 192315, 192335, 192336, 192337, 192340, 192346, 192347, 192348, 192351, 192446, 192447, 192452, 192471, 192472, 192473, 192477, 192482, 192483, 192484, 192488, 192566, 192567, 192572, 192591, 192592, 192593, 192597, 192602, 192603, 192604, 192608, 197131, 197132, 197133, 197134, 197136, 197137, 197167, 197168, 197169, 197170, 197172, 197173, 197308, 197309, 197312, 197322, 197323, 197326, 197347, 197348, 197351, 197358, 197359, 197362, 197887, 197889, 197893, 197901, 197903, 197907, 197926, 197928, 197932, 197937, 197939, 197943, 250159, 250160, 250161, 250162, 250174, 250175, 250181, 250182, 250194, 250195, 250196, 250197, 250198, 250199, 250200, 250201, 251034, 251035, 251036, 251037, 251043, 251044, 251045, 251046, 251049, 251050, 251056, 251057, 251069, 251070, 251071, 251072, 251073, 251074, 251075, 251076, 251126, 251127, 251135, 251136, 251140, 251141, 251147, 251148, 251161, 251162, 251165, 251166, 251324, 251327, 251333, 251336, 251339, 251340, 251346, 251347, 251359, 251362, 251363, 251366, 252003, 252004, 252005, 252006, 252012, 252013, 252014, 252015, 252018, 252025, 252038, 252039, 252040, 252041, 252139, 252140, 252141, 252142, 252148, 252149, 252150, 252151, 252155, 252162, 252178, 252179, 252180, 252181, 252456, 252457, 252465, 252466, 252470, 252471, 252477, 252478, 252491, 252492, 252495, 252496, 252654, 252657, 252663, 252666, 252669, 252670, 252676, 252677, 252689, 252692, 252693, 252696, 252990, 252991, 252992, 252993, 252999, 253000, 253001, 253002, 253005, 253012, 253025, 253026, 253027, 253028, 253504, 253505, 253506, 253507, 253513, 253514, 253515, 253516, 253519, 253526, 253539, 253540, 253541, 253542, 253596, 253597, 253605, 253606, 253610, 253617, 253631, 253632, 253794, 253797, 253803, 253806, 253809, 253816, 253829, 253832, 254368, 254369, 254370, 254371, 254377, 254378, 254379, 254380, 254384, 254391, 254407, 254408, 254409, 254410, 254565, 254566, 254574, 254575, 254579, 254580, 254586, 254587, 254600, 254601, 254604, 254605, 254763, 254766, 254772, 254775, 254778, 254779, 254785, 254786, 254798, 254801, 254802, 254805, 255289, 255290, 255291, 255292, 255298, 255299, 255300, 255301, 255304, 255311, 255324, 255325, 255326, 255327, 255381, 255382, 255390, 255391, 255395, 255402, 255416, 255417, 255579, 255582, 255588, 255591, 255594, 255601, 255614, 255617, 255969, 255970, 255971, 255972, 255978, 255979, 255980, 255981, 255985, 255992, 256008, 256009, 256010, 256011, 256061, 256062, 256070, 256071, 256076, 256083, 256100, 256101, 256259, 256262, 256268, 256271, 256275, 256282, 256298, 256301, 256529, 256530, 256531, 256532, 256538, 256539, 256540, 256541, 256545, 256552, 256568, 256569, 256570, 256571, 256621, 256622, 256630, 256631, 256636, 256643, 256660, 256661, 256819, 256822, 256828, 256831, 256835, 256842, 256858, 256861, 262818, 262819, 262820, 262821, 262824, 262825, 262831, 262832, 262844, 262845, 262846, 262847, 262848, 262849, 262850, 262851, 263776, 263777, 263785, 263786, 263790, 263791, 263797, 263798, 263811, 263812, 263815, 263816, 263919, 263920, 263921, 263922, 263928, 263929, 263930, 263931, 263934, 263935, 263941, 263942, 263954, 263955, 263956, 263957, 263958, 263959, 263960, 263961, 263974, 263977, 263983, 263986, 263989, 263990, 263996, 263997, 264009, 264012, 264013, 264016, 264653, 264654, 264655, 264656, 264662, 264663, 264664, 264665, 264668, 264675, 264688, 264689, 264690, 264691, 264789, 264790, 264791, 264792, 264798, 264799, 264800, 264801, 264805, 264812, 264828, 264829, 264830, 264831, 265106, 265107, 265115, 265116, 265120, 265121, 265127, 265128, 265141, 265142, 265145, 265146, 265304, 265307, 265313, 265316, 265319, 265320, 265326, 265327, 265339, 265342, 265343, 265346, 265640, 265641, 265642, 265643, 265649, 265650, 265651, 265652, 265655, 265662, 265675, 265676, 265677, 265678, 266246, 266247, 266255, 266256, 266260, 266267, 266281, 266282, 266389, 266390, 266391, 266392, 266398, 266399, 266400, 266401, 266404, 266411, 266424, 266425, 266426, 266427, 266444, 266447, 266453, 266456, 266459, 266466, 266479, 266482, 267018, 267019, 267020, 267021, 267027, 267028, 267029, 267030, 267034, 267041, 267057, 267058, 267059, 267060, 267215, 267216, 267224, 267225, 267229, 267230, 267236, 267237, 267250, 267251, 267254, 267255, 267413, 267416, 267422, 267425, 267428, 267429, 267435, 267436, 267448, 267451, 267452, 267455, 268031, 268032, 268040, 268041, 268045, 268052, 268066, 268067, 268174, 268175, 268176, 268177, 268183, 268184, 268185, 268186, 268189, 268196, 268209, 268210, 268211, 268212, 268229, 268232, 268238, 268241, 268244, 268251, 268264, 268267, 268711, 268712, 268720, 268721, 268726, 268733, 268750, 268751, 268854, 268855, 268856, 268857, 268863, 268864, 268865, 268866, 268870, 268877, 268893, 268894, 268895, 268896, 268909, 268912, 268918, 268921, 268925, 268932, 268948, 268951, 269271, 269272, 269280, 269281, 269286, 269293, 269310, 269311, 269414, 269415, 269416, 269417, 269423, 269424, 269425, 269426, 269430, 269437, 269453, 269454, 269455, 269456, 269469, 269472, 269478, 269481, 269485, 269492, 269508, 269511, 273558, 273559, 273572, 273573, 273597, 273598, 273608, 273609, 274138, 274139, 274152, 274153, 274177, 274178, 274188, 274189, 291916, 291917, 291923, 291924, 292115, 292116, 292122, 292123, 292950, 292951, 292952, 292953, 292959, 292960, 292961, 292962, 292969, 292970, 292974, 292975, 292985, 292986, 292987, 292988, 293042, 293043, 293051, 293052, 293060, 293066, 293077, 293078, 293185, 293186, 293187, 293188, 293194, 293195, 293196, 293197, 293204, 293205, 293209, 293210, 293220, 293221, 293222, 293223, 293240, 293243, 293249, 293252, 293260, 293264, 293275, 293278, 295975, 295976, 295977, 295978, 295984, 295985, 295986, 295987, 295994, 295995, 295999, 296000, 296014, 296015, 296016, 296017, 296067, 296068, 296076, 296077, 296085, 296091, 296106, 296107, 296210, 296211, 296212, 296213, 296219, 296220, 296221, 296222, 296229, 296230, 296234, 296235, 296249, 296250, 296251, 296252, 296265, 296268, 296274, 296277, 296285, 296289, 296304, 296307, 381718, 381720, 381721, 381723, 381724, 381759, 381760, 381762, 381763, 381837, 381839, 381840, 381842, 381843, 381862, 381865, 381867, 381868, 381873, 381875, 381876, 381878, 381879, 382584, 382585, 382586, 382587, 382599, 382600, 382606, 382607, 382619, 382620, 382621, 382622, 382623, 382624, 382625, 382626, 382960, 382961, 382964, 382965, 382967, 382968, 382969, 382970, 382980, 382981, 382982, 382983, 382984, 382985, 382986, 382987, 383551, 383552, 383565, 383566, 383569, 383572, 383573, 383575, 383586, 383587, 383590, 383591, 383694, 383695, 383696, 383697, 383709, 383710, 383713, 383714, 383716, 383717, 383718, 383719, 383729, 383730, 383731, 383732, 383733, 383734, 383735, 383736, 383749, 383752, 383764, 383765, 383769, 383771, 383772, 383773, 383784, 383787, 383788, 383791, 385184, 385185, 385186, 385187, 385193, 385194, 385195, 385196, 385199, 385200, 385206, 385207, 385219, 385220, 385221, 385222, 385223, 385224, 385225, 385226, 385554, 385555, 385556, 385557, 385560, 385561, 385564, 385565, 385567, 385568, 385569, 385570, 385580, 385581, 385582, 385583, 385584, 385585, 385586, 385587, 386151, 386152, 386160, 386161, 386165, 386166, 386169, 386172, 386173, 386175, 386186, 386187, 386190, 386191, 386349, 386352, 386358, 386361, 386364, 386365, 386369, 386371, 386372, 386373, 386384, 386387, 386388, 386391, 388896, 388898, 388900, 388901, 389015, 389017, 389019, 389020, 389040, 389042, 389044, 389045, 389051, 389053, 389055, 389056, 389126, 389127, 389129, 389131, 389132, 389166, 389168, 389170, 389171, 389245, 389246, 389248, 389250, 389251, 389270, 389271, 389273, 389275, 389276, 389281, 389282, 389284, 389286, 389287, 389508, 389509, 389517, 389518, 389523, 389524, 389543, 389544, 389547, 389548, 389878, 389879, 389884, 389885, 389893, 389894, 389904, 389905, 389908, 389909, 390475, 390484, 390489, 390490, 390499, 390510, 390514, 390618, 390619, 390627, 390628, 390633, 390634, 390642, 390643, 390653, 390654, 390657, 390658, 390673, 390682, 390688, 390689, 390697, 390708, 390712, 391288, 391289, 391290, 391291, 391294, 391295, 391301, 391302, 391314, 391315, 391316, 391317, 391318, 391319, 391320, 391321, 392255, 392256, 392260, 392261, 392264, 392267, 392268, 392270, 392281, 392282, 392285, 392286, 392398, 392399, 392400, 392401, 392404, 392405, 392408, 392409, 392411, 392412, 392413, 392414, 392424, 392425, 392426, 392427, 392428, 392429, 392430, 392431, 392453, 392456, 392459, 392460, 392464, 392466, 392467, 392468, 392479, 392482, 392483, 392486, 392819, 392820, 392821, 392822, 392828, 392829, 392830, 392831, 392834, 392835, 392841, 392842, 392854, 392855, 392856, 392857, 392858, 392859, 392860, 392861, 393189, 393190, 393191, 393192, 393195, 393196, 393199, 393200, 393202, 393203, 393204, 393205, 393215, 393216, 393217, 393218, 393219, 393220, 393221, 393222, 393786, 393787, 393795, 393796, 393800, 393801, 393804, 393807, 393808, 393810, 393821, 393822, 393825, 393826, 393929, 393930, 393931, 393932, 393938, 393939, 393940, 393941, 393944, 393945, 393948, 393949, 393951, 393952, 393953, 393954, 393964, 393965, 393966, 393967, 393968, 393969, 393970, 393971, 393984, 393987, 393993, 393996, 393999, 394000, 394004, 394006, 394007, 394008, 394019, 394022, 394023, 394026, 413183, 413186, 413188, 413189, 413288, 413291, 413293, 413294, 413302, 413305, 413307, 413308, 413338, 413341, 413343, 413344, 414049, 414050, 414051, 414052, 414064, 414065, 414071, 414072, 414084, 414085, 414086, 414087, 414088, 414089, 414090, 414091, 414924, 414925, 414926, 414927, 414939, 414940, 414943, 414944, 414946, 414947, 414948, 414949, 414959, 414960, 414961, 414962, 414963, 414964, 414965, 414966, 415016, 415017, 415030, 415031, 415034, 415037, 415038, 415040, 415051, 415052, 415055, 415056, 415214, 415217, 415229, 415230, 415234, 415236, 415237, 415238, 415249, 415252, 415253, 415256, 418949, 418950, 418951, 418952, 418958, 418959, 418960, 418961, 418964, 418965, 418971, 418972, 418984, 418985, 418986, 418987, 418988, 418989, 418990, 418991, 419310, 419311, 419312, 419313, 419325, 419326, 419329, 419330, 419332, 419333, 419334, 419335, 419345, 419346, 419347, 419348, 419349, 419350, 419351, 419352, 419916, 419917, 419925, 419926, 419930, 419931, 419934, 419937, 419938, 419940, 419951, 419952, 419955, 419956, 420114, 420117, 420123, 420126, 420129, 420130, 420134, 420136, 420137, 420138, 420149, 420152, 420153, 420156, 420361, 420362, 420363, 420365, 420366, 420401, 420402, 420404, 420405, 420466, 420468, 420470, 420471, 420480, 420481, 420482, 420484, 420485, 420516, 420517, 420518, 420520, 420521, 420591, 420592, 420594, 420596, 420597, 420630, 420633, 420635, 420636, 420696, 420697, 420699, 420701, 420702, 420710, 420711, 420713, 420715, 420716, 420746, 420747, 420749, 420751, 420752, 420973, 420974, 420982, 420983, 420988, 420989, 421008, 421009, 421012, 421013, 421334, 421335, 421349, 421350, 421358, 421359, 421369, 421370, 421373, 421374, 421848, 421849, 421857, 421858, 421863, 421864, 421872, 421873, 421883, 421884, 421887, 421888, 421940, 421949, 421954, 421955, 421964, 421975, 421979, 422138, 422147, 422153, 422154, 422162, 422173, 422177, 422753, 422754, 422755, 422756, 422759, 422760, 422766, 422767, 422779, 422780, 422781, 422782, 422783, 422784, 422785, 422786, 423120, 423121, 423124, 423125, 423127, 423128, 423129, 423130, 423140, 423141, 423142, 423143, 423144, 423145, 423146, 423147, 423628, 423629, 423630, 423631, 423634, 423635, 423638, 423639, 423641, 423642, 423643, 423644, 423654, 423655, 423656, 423657, 423658, 423659, 423660, 423661, 423720, 423721, 423725, 423726, 423729, 423732, 423733, 423735, 423746, 423747, 423750, 423751, 423918, 423921, 423924, 423925, 423929, 423931, 423932, 423933, 423944, 423947, 423948, 423951, 424284, 424285, 424286, 424287, 424293, 424294, 424295, 424296, 424299, 424300, 424306, 424307, 424319, 424320, 424321, 424322, 424323, 424324, 424325, 424326, 424645, 424646, 424647, 424648, 424660, 424661, 424664, 424665, 424667, 424668, 424669, 424670, 424680, 424681, 424682, 424683, 424684, 424685, 424686, 424687, 425159, 425160, 425161, 425162, 425168, 425169, 425170, 425171, 425174, 425175, 425178, 425179, 425181, 425182, 425183, 425184, 425194, 425195, 425196, 425197, 425198, 425199, 425200, 425201, 425251, 425252, 425260, 425261, 425265, 425266, 425269, 425272, 425273, 425275, 425286, 425287, 425290, 425291, 425449, 425452, 425458, 425461, 425464, 425465, 425469, 425471, 425472, 425473, 425484, 425487, 425488, 425491, 433486, 433489, 433492, 433591, 433594, 433596, 433597, 433605, 433608, 433610, 433611, 433630, 433633, 433635, 433636, 433641, 433644, 433646, 433647, 434641, 434643, 434645, 434746, 434748, 434750, 434751, 434760, 434762, 434764, 434765, 434785, 434787, 434789, 434790, 434796, 434798, 434800, 434801, 436130, 436131, 436139, 436140, 436165, 436166, 436169, 436170, 436365, 436366, 436374, 436375, 436400, 436401, 436404, 436405, 440588, 440590, 440594, 440693, 440695, 440698, 440699, 440707, 440709, 440712, 440713, 440732, 440737, 440738, 440743, 440745, 440748, 440749, 441454, 441455, 441456, 441457, 441473, 441474, 441478, 441479, 441493, 441494, 441495, 441496, 442329, 442330, 442331, 442332, 442348, 442349, 442353, 442354, 442364, 442365, 442366, 442367, 442368, 442369, 442370, 442371, 442421, 442422, 442439, 442445, 442456, 442457, 442460, 442461, 442564, 442565, 442566, 442567, 442583, 442584, 442588, 442589, 442599, 442600, 442601, 442602, 442603, 442604, 442605, 442606, 442619, 442622, 442639, 442643, 442654, 442657, 442658, 442661, 447766, 447767, 447770, 447871, 447875, 447876, 447885, 447886, 447889, 447890, 447910, 447911, 447914, 447915, 447921, 447922, 447925, 447926, 448378, 448379, 448387, 448388, 448393, 448394, 448413, 448414, 448417, 448418, 448754, 448755, 449254, 449263, 449268, 449269, 449289, 449293, 449345, 449354, 449359, 449360, 449380, 449384, 449488, 449497, 449503, 449504, 449523, 449527, 449543, 449552, 449558, 449559, 449578, 449582, 450158, 450159, 450160, 450161, 450168, 450169, 450173, 450174, 450184, 450185, 450186, 450187, 451033, 451034, 451035, 451036, 451043, 451044, 451048, 451049, 451059, 451060, 451061, 451062, 451063, 451064, 451065, 451066, 451125, 451126, 451134, 451140, 451151, 451152, 451155, 451156, 451268, 451269, 451270, 451271, 451278, 451279, 451283, 451284, 451294, 451295, 451296, 451297, 451298, 451299, 451300, 451301, 451323, 451326, 451334, 451338, 451349, 451352, 451353, 451356, 464339, 464341, 464342, 464344, 464345, 464444, 464446, 464447, 464449, 464450, 464458, 464460, 464461, 464463, 464464, 464483, 464486, 464488, 464489, 464494, 464496, 464497, 464499, 464500, 465090, 465107, 465652, 465666, 465691, 465702, 465788, 465802, 465827, 465838, 466082, 466083, 466099, 466100, 466117, 466118, 466121, 466122, 466317, 466318, 466334, 466335, 466352, 466353, 466356, 466357, 467423, 467425, 467428, 467429, 467462, 467463, 467464, 467467, 467468, 467528, 467529, 467530, 467533, 467534, 467542, 467543, 467544, 467547, 467548, 467578, 467579, 467580, 467583, 467584, 467690, 467691, 467707, 467708, 468252, 468253, 468266, 468267, 468302, 468303, 468388, 468389, 468402, 468403, 468438, 468439, 468682, 468683, 468691, 468692, 468699, 468700, 468717, 468718, 468721, 468722, 469724, 469725, 469728, 469729, 469762, 469763, 469764, 469767, 469768, 469842, 469843, 469844, 469847, 469848, 469867, 469868, 469869, 469872, 469873, 469878, 469879, 469880, 469883, 469884, 469990, 469991, 470007, 470008, 470566, 470567, 470591, 470592, 470602, 470603, 470702, 470703, 470727, 470728, 470738, 470739, 471217, 471218, 471226, 471227, 471234, 471235, 471252, 471253, 471256, 471257, 471517, 471518, 471519, 471521, 471522, 471622, 471624, 471626, 471627, 471636, 471637, 471638, 471640, 471641, 471661, 471662, 471663, 471665, 471666, 471672, 471673, 471674, 471676, 471677};

exportData = <||>;
candidateIds = {};
If[otherLayers == {3}, candidateIds = candidateIdsLayer3 ];
If[otherLayers == {7}, candidateIds = candidateIdsLayer7 ];
If[otherLayers == {5}, candidateIds = candidateIdsLayer5Partial ];

For[candidateId = 1, candidateId <= Length[treeCandidates], candidateId++,
	If[MemberQ[candidateIds, candidateId] == False, Continue[]];

	(* 
	with layer 3:
	achieving 70 distinct cells: {29942, .... 111692}
	2022-12-21T18:08:33 candidateId = 29942 out of 111930
		70
		before folding, w-coordinates by layer
		{-1., -0.80901699, -0.30901699, 0., 0.30901699, 0.80901699, 1.}
		{1, 12, 12, 20, 12, 12, 1}
		layer counts match before and after folding
		Found a good net matching cell count
		Element counts: cells, faces, edges, vertices:
		{70, 0, 0, 0}
	*)

	edgeGroups = treeCandidates[[candidateId]];
	(* Print["cross layer shifted edge count: " <> IntegerString[Length[shiftedEdges]]]; *)

	combinedGraph = Graph[Join[Apply[Join, edgeGroups], fixedEdges]];

	If[ConnectedGraphQ[combinedGraph] == False, 
		(* Print["Graph is not connected. Skip"]; *)
		Continue[];
	];

	If[TreeGraphQ[combinedGraph] == False,
		(* Print["unexpected: combined graph is not a tree"]; *)
		Continue[];
	];

	Print[];
	Print[DateString["ISODateTime"] <> " candidateId = " <> IntegerString[candidateId]
		<> " out of " <> IntegerString[Length[treeCandidates]]
	];

	(* Print[crossBundleEdges]; *)

(* 	components = ConnectedGraphComponents[combinedGraph, {41}];
	combinedGraph = components[[1]]; *)

	(* Print[VertexCount[combinedGraph]]; *)
	highlightedCellIds = VertexList[combinedGraph]//Sort;
	Print[highlightedCellIds//Length];

	combinedTree = GraphTree[combinedGraph, 41];
	rotationSchedule = {};
	rotationSchedule = buildSchedule[combinedTree, rotationSchedule, 1];
	maxLevel = Max[Map[#[[3]]&, rotationSchedule ]];
	foldPercents = Table[-1, {k, maxLevel}];
	rotatedCells = foldCells[cells, rotationSchedule, foldPercents];

	shiftedOtherCentersRounded = Round[shiftedOtherCenters, epsilon];

(* 	Print[candidateId];
	Print[edgeGroups];
	Print[edgeGroups//Length];
 *)
(* 	Print[shiftedOtherCentersRounded];
	Print[shiftedOtherCentersRounded//Length];
	Print[shiftedOtherCentersRounded[[1]]];
	Print[otherLayerLengths];
 *)
	exportData[{candidateId}] = {
		edgeGroups,
		shiftedOtherCentersRounded,
		otherLayerLengths
	};
];

fileName = "candidateStep2_layer_";
If[otherLayers == {3}, fileName = fileName <> "3" ];
If[otherLayers == {7}, fileName = fileName <> "7" ];
If[otherLayers == {5}, fileName = fileName <> "5" ];

exportDataFileName = FileNameJoin[{dataFolder, "folding_120_cell", fileName <> ".wl"}];

If[FileExistsQ[exportDataFileName], DeleteFile[exportDataFileName]];
Save[exportDataFileName, exportData];


Exit[];




(* negativeFold = True; *)
negativeFold = False;

For[frameId = 0, frameId <= 10, frameId += 1,
	foldPercents = Table[If[negativeFold, -1, 1] * 0.1 * frameId, {k, 10}];
	rotatedCells = foldCells[cells, rotationSchedule, foldPercents];
	exportImage[shape, rotatedCells, 0.01, 0, frameId + If[negativeFold, 100, 0]];
];



(* exportImage[shape, 1, 9, 2.9, 1 deltaTheta, 11]; *)
(* exportImage[shape, 1, 9, 2.9, 2 deltaTheta, 12]; *)
(* exportImage[shape, 1, 9, 2.9, 3 deltaTheta, 13]; *)
(* exportImage[shape, 1, 9, 2.9, 4 deltaTheta, 14]; *)

(* 	dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];
	Print["Reading data for " <> shape <> " from " <> dataFileName];

	cells = Get[dataFileName];
	Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];
 *)

(* 
0.01, -0.01, signature = -1, candidate id = 50: 100 cells
0.01, -0.01, signature depends on bundle, candidate id = 100: 100 cells

 *)