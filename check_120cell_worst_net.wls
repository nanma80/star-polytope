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
doubleRotationMatrix[theta_] := ArrayFlatten[{{RotationMatrix[-theta], 0}, {0, RotationMatrix[-theta]}}];
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

	fullProjectionMatrix = doubleRotationMatrix[theta];

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

getNeighborEdgeLists[selectedEdges_, graphEdgeList_, neighborDistance_] := Module[
	{neighbors, minusEdgeId, remainingSelectedEdges, neighborEdgeLists, neighborEdgeListsAsTree},
	neighbors = {};
	minusEdgeIds = Subsets[Range[Length[selectedEdges]], {neighborDistance}];

	For[minusEdgeId = 1, minusEdgeId <= Length[selectedEdges], minusEdgeId++,
		minusEdges = minusEdgeIds[[minusEdgeId]];
		remainingSelectedEdges = selectedEdges[[ Complement[Range[Length[selectedEdges]], minusEdges ]]];

		neighborEdgeLists = Map[ Union[#, remainingSelectedEdges]& , Subsets[graphEdgeList, {neighborDistance} ]];
		neighborEdgeLists = Select[neighborEdgeLists, Length[#] == Length[remainingSelectedEdges] + neighborDistance &];

		neighborEdgeListsAsTree = Select[neighborEdgeLists, TreeGraphQ[Graph[#]] &];
		neighbors = Join[neighbors, Map[Sort, neighborEdgeListsAsTree]];
	];

	Union[neighbors]
];

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

	rotatedCells
];


testFold[cells_, rotationSchedule_, foldPercents_] := Module[
	{},

	(* Return[]; *)
	(* If[frameIndex <= 248, Return[]]; *)
	(* If[EvenQ[frameIndex] == True, Return[]]; *)
	(* If[EvenQ[frameIndex] == False, Return[]]; *)

	rotatedCells = foldCells[cells, rotationSchedule, foldPercents];

	rotatedCellCenters = Map[getCellCenter, rotatedCells];

	rotatedCellCentersTally = Tally[rotatedCellCenters, ApproxSamePoint[#1, #2]&];
	cellTallyCounts = Sort[Map[#[[2]]&, rotatedCellCentersTally], Greater];

	uniqueCenters = Union[rotatedCellCenters, SameTest -> ApproxSamePoint];
	uniqueCentersCount = Length[uniqueCenters];
	distanceLevels = Map[Length[Tally[#, ApproxSamePoint[#1, #2] &]] &, Table[EuclideanDistance[uniqueCenters[[i]], uniqueCenters[[j]]], {i, uniqueCentersCount}, {j, uniqueCentersCount}]];

	distanceLevelsTally = Sort[Tally[distanceLevels]];

(* 	rotatedEdges = Flatten[Map[getEdgesFromFace, rotatedFaces], 1];
	rotatedEdgeCenters = Map[Mean, rotatedEdges];
	rotatedEdgeCentersTally = Tally[rotatedEdgeCenters, ApproxSamePoint[#1, #2]&];
	edgeTallyCounts = Sort[Map[#[[2]]&, rotatedEdgeCentersTally], Greater]; *)
	(* Print[edgeTallyCounts]; *)
	{cellTallyCounts, distanceLevelsTally}
];


orientedCellCenters = cellCenters;
orientedCellCentersMap = <||>;
For[cid = 1, cid <= Length[cellCenters], cid++,
  cellCenter = cellCenters[[cid]];
  orientedCellCentersMap[Round[cellCenter, epsilon]] = cid;
  ];

rotatedCids = 
  Table[orientedCellCentersMap[
    Round[cellCenters[[cid]].doubleRotationMatrix[k Pi/5], 
     epsilon]], {cid, 1, 120}, {k, -4, 5}];
orbits = Map[#[[1]] &, Tally[rotatedCids, Sort[#1] == Sort[#2] &]];
orbitMap = <||>;

objectiveDirection1 = {0, 0.000, 0.01, 1};
objectiveDirection2 = {-0.01, 1, 0, 0};
subgraphIds = {};
orbitSeeds = {};
For[orbitId = 1, orbitId <= Length[orbits], orbitId++,
  orbit = orbits[[orbitId]];
  For[cid = 1, cid <= Length[orbit], cid++,
  	cell = orbit[[cid]];
  	orbitMap[cell] = orbitId;
  ];
  minW = Min[
    Map[Min[orientedCellCenters[[#]] . objectiveDirection1, 
       orientedCellCenters[[#]] . objectiveDirection2] &, orbit]];
  minWIds = 
   Select[orbit, 
    Abs[Min[orientedCellCenters[[#]] . objectiveDirection1, 
         orientedCellCenters[[#]] . objectiveDirection2] - minW] < 
      epsilon &];
  subgraphIds = Join[subgraphIds, minWIds];
  AppendTo[orbitSeeds, minWIds];
];

Map[Print[{#, N[orientedCellCenters[[#]]]}]&, subgraphIds];

(* one orbit *)
(* subgraphIds = Select[subgraphIds, orientedCellCenters[[#]][[4]] < -2.5 & ]; *)
(* subgraphIds = {41}; *)

(* subgraphIds = {41, 79}; *)

(* 3 orbits *)
(* subgraphIds = Select[subgraphIds, orientedCellCenters[[#]][[4]] < -2 && orientedCellCenters[[#]][[1]] < epsilon & ]; *)

(* subgraphIds = {41, 79, 42}; *)
(* subgraphIds = {41, 42, 89}; *)

(* 4 orbits *)
(* subgraphIds = Select[subgraphIds, orientedCellCenters[[#]][[4]] < -2 && orientedCellCenters[[#]][[1]] > - epsilon & ]; *)

(* subgraphIds = {41, 42, 89, 79}; *)

(* six orbits *)
(* subgraphIds = Select[subgraphIds, orientedCellCenters[[#]][[4]] < -2 & ]; *)
(* focusedOrbits = {7, 4, 2, 3, 5, 12}; *)
bundle1 = {7, 4, 2, 3, 5, 12};
focusedOrbits = Range[12];
(* focusedOrbits = bundle1; *)

(* subgraphIds = Select[Range[Length[cells]], MemberQ[focusedOrbits, orbitMap[#]]& ]; *)
subgraphIds = Select[subgraphIds, MemberQ[focusedOrbits, orbitMap[#]]& ];


Print[subgraphIds];
Print[subgraphIds//Length];

(* Print[orbitMap]; *)
(* Map[Print[{#,orbitMap[#]}]&, subgraphIds]; *)

centersBeforeFolding = orientedCellCenters[[subgraphIds]];
fibrationsBeforeFolding = Map[mapHopfFibration[normalized[#]]&, centersBeforeFolding];
Print[Tally[fibrationsBeforeFolding]];

(* otherOrbit = orientedCellCenters[[orbits[[4]]]];
Map[Print[Round[#/phi^2*2, epsilon]]&, otherOrbit];

otherOrbitNorm = Cross[otherOrbit[[1]][[Range[3]]], otherOrbit[[2]][[Range[3]]]]//N;
If[Norm[otherOrbitNorm] > epsilon, otherOrbitNorm = otherOrbitNorm/Norm[otherOrbitNorm]];
Print["otherOrbitNorm before folding"];
Print[otherOrbitNorm];
otherOrbitNorm = Cross[otherOrbit[[3]][[Range[3]]], otherOrbit[[4]][[Range[3]]]]//N;
If[Norm[otherOrbitNorm] > epsilon, otherOrbitNorm = otherOrbitNorm/Norm[otherOrbitNorm]];
Print[otherOrbitNorm];
otherOrbitNorm = Cross[otherOrbit[[5]][[Range[3]]], otherOrbit[[6]][[Range[3]]]]//N;
If[Norm[otherOrbitNorm] > epsilon, otherOrbitNorm = otherOrbitNorm/Norm[otherOrbitNorm]];
Print[otherOrbitNorm];
otherOrbitNorm = Cross[otherOrbit[[7]][[Range[3]]], otherOrbit[[8]][[Range[3]]]]//N;
If[Norm[otherOrbitNorm] > epsilon, otherOrbitNorm = otherOrbitNorm/Norm[otherOrbitNorm]];
Print[otherOrbitNorm]; *)

(* z-coordinate of otherOrbitNorm: 0.5257311121191337, 0.85065080835204, 1 *)
(* Exit[]; *)

edges = {};
For[subId1 = 1, subId1 <= Length[subgraphIds] - 1, subId1++,
  For[subId2 = subId1 + 1, subId2 <= Length[subgraphIds], subId2++,
    id1 = subgraphIds[[subId1]];
    id2 = subgraphIds[[subId2]];
    If[orbitMap[id1] == orbitMap[id2], Continue[]];
    If[id1 != 41 && id2 != 41 && id1 != 59 && id2 != 59, Continue[]];
    (* If[id1 != 41 && id2 != 41 , Continue[]]; *)
    If[adjacentCellsIndex[cells, id1, id2],
     AppendTo[edges, id1 \[UndirectedEdge] id2];
     ];
    ];
  ];

Print["cross orbit prototype edge count: " <> IntegerString[Length[edges]]];

Print[edges];
edges = Select[edges, #[[1]]!= 5 && #[[2]]!= 5 &];
edges = Select[edges, #[[1]]!= 28 && #[[2]]!= 28 &];
(* AppendTo[edges, 5 \[UndirectedEdge] 41 ]; *)
AppendTo[edges, 5 \[UndirectedEdge] 6 ];
AppendTo[edges, 28 \[UndirectedEdge] 70 ];

shiftedEdges = {};
For[edgeId = 1, edgeId <= Length[edges], edgeId++,
	edge = edges[[edgeId]];
	bundleId = If[
		edge[[1]] == 41 || edge[[2]] == 41,
		1,
		2
	];
	For[k = -4, k <= 5, k++,
		id1 = orientedCellCentersMap[
	     Round[orientedCellCenters[[edge[[1]] ]] . 
	       doubleRotationMatrix[k Pi/5], epsilon]];
	    id2 = orientedCellCentersMap[
	     Round[orientedCellCenters[[edge[[2]] ]] . 
	       doubleRotationMatrix[k Pi/5], epsilon]];
	    AppendTo[shiftedEdges, id1 \[UndirectedEdge] id2];
	];
];

Print["cross orbit shifted edge count: " <> IntegerString[Length[shiftedEdges]]];
(* Exit[]; *)

subgraph = Graph[subgraphIds, edges, VertexLabels -> "Name"];
edgesInOrbits = {};
For[orbitId = 1, orbitId <= Length[orbitSeeds], orbitId++,
  If[orbitId != 1 && orbitId != 7, Continue[]];
  orbitSeed = orbitSeeds[[orbitId]];
  If[Length[orbitSeed] > 1, Continue[]];
  orbitIds = 
   Table[orientedCellCentersMap[
     Round[orientedCellCenters[[orbitSeed[[1]]]] . 
       doubleRotationMatrix[k Pi/5], epsilon]], {k, -4, 5}];
  orbitEdges = 
   Table[UndirectedEdge[orbitIds[[k]], orbitIds[[k + 1]]], {k, 
     Length[orbitIds] - 1}];
  edgesInOrbits = Join[edgesInOrbits, orbitEdges];
];

Print[edgesInOrbits];

crossBundleEdges = {};
(* example of a bundle on the 41 side *)
id1s = {5};
(* id1s = {2, 5, 22, 25, 34, 43, 94, 100, 106, 113}; *)
For[id1Id = 1, id1Id <= Length[id1s], id1Id++,
	id1 = id1s[[id1Id]];
	For[id2 = 1, id2 <= Length[cells], id2++,
		If[adjacentCellsIndex[cells, id1, id2],
			orbitId2 = orbitMap[id2];
			If[MemberQ[bundle1, orbitId2] == False,
				AppendTo[crossBundleEdges, id1 \[UndirectedEdge] id2]
			];
		];
	];
];

Print[crossBundleEdges];

(* 
{34 \[UndirectedEdge] 52, 34 \[UndirectedEdge] 54, 34 \[UndirectedEdge] 61, 34 \[UndirectedEdge] 76}
 *)
(* crossBundleCellIds = {34, 52}; *)

(* topN = 121; *)
(* topN = 1000; *)
(* topN = 10 * 1000 * 1000; *)
(* topN = 705432; *)
(* treeCandidates = 
  Select[TreeGraphQ[Graph@#] &]@
   Select[VertexCount@# == VertexCount[subgraph] &]@
    Subsets[EdgeList[subgraph], {VertexCount[subgraph] - 1}, topN]; *)


(* treeCandidates = Subsets[edges, {Length[focusedOrbits] - 1}, topN]; *)
(* treeCandidates = {edges}; *)
treeCandidates = Map[{#}&, crossBundleEdges];
(* treeCandidates = {}; *)

Print["Found trees as candidates: " <> IntegerString[Length[treeCandidates]]];
If[Length[treeCandidates] == 0,
	treeCandidates = { {} };
];

maxCellCount = 1000;

adjMatrixFileName = FileNameJoin[{dataFolder, "folding_120_cell", "adjMatrix.wl"}];
If[FileExistsQ[adjMatrixFileName],
	adjMatrix = Get[adjMatrixFileName],
	(* construct adjMatrix *)
	limit = Length[cells];
	adjMatrix = {};

	For[id1 = 1, id1 <= limit, id1++,
		row = Table[If[adjacentCellsIndex[cells, id1, id2], 1, 0], 
			{id2, 1, limit}];
		Print[id1];
		AppendTo[adjMatrix, row];
	];

	Print[adjMatrix];

	Save[adjMatrixFileName, adjMatrix];

];


graph = AdjacencyGraph[Range[Length[adjMatrix]], adjMatrix ];
graphEdgeList = EdgeList[graph];
graphEdgeList = Sort[Map[Sort[#] &, graphEdgeList]];

randomSubset = graphEdgeList;
spanningTree = FindSpanningTree[Graph[randomSubset]];
tree = GraphTree[spanningTree];
treeEdgeList = EdgeList[spanningTree];
(* treeEdgeList = Sort[Map[Sort[#] &, treeEdgeList]]; *)

(* 33 unique cells *)
treeEdgeList = {1 \[UndirectedEdge] 8, 1 \[UndirectedEdge] 12, 1 \[UndirectedEdge] 14, 1 \[UndirectedEdge] 19, 1 \[UndirectedEdge] 29, 1 \[UndirectedEdge] 52, 1 \[UndirectedEdge] 53, 1 \[UndirectedEdge] 54, 1 \[UndirectedEdge] 59, 1 \[UndirectedEdge] 61, 1 \[UndirectedEdge] 65, 1 \[UndirectedEdge] 102, 2 \[UndirectedEdge] 3, 2 \[UndirectedEdge] 5, 2 \[UndirectedEdge] 6, 2 \[UndirectedEdge] 10, 2 \[UndirectedEdge] 13, 2 \[UndirectedEdge] 15, 2 \[UndirectedEdge] 25, 2 \[UndirectedEdge] 31, 2 \[UndirectedEdge] 104, 2 \[UndirectedEdge] 110, 3 \[UndirectedEdge] 12, 3 \[UndirectedEdge] 27, 3 \[UndirectedEdge] 30, 3 \[UndirectedEdge] 51, 3 \[UndirectedEdge] 60, 4 \[UndirectedEdge] 7, 4 \[UndirectedEdge] 14, 4 \[UndirectedEdge] 16, 4 \[UndirectedEdge] 17, 4 \[UndirectedEdge] 20, 4 \[UndirectedEdge] 32, 4 \[UndirectedEdge] 36, 4 \[UndirectedEdge] 40, 5 \[UndirectedEdge] 41, 6 \[UndirectedEdge] 42, 6 \[UndirectedEdge] 56, 6 \[UndirectedEdge] 103, 7 \[UndirectedEdge] 22, 7 \[UndirectedEdge] 23, 7 \[UndirectedEdge] 43, 8 \[UndirectedEdge] 9, 8 \[UndirectedEdge] 18, 8 \[UndirectedEdge] 21, 9 \[UndirectedEdge] 11, 9 \[UndirectedEdge] 64, 10 \[UndirectedEdge] 55, 11 \[UndirectedEdge] 69, 12 \[UndirectedEdge] 28, 13 \[UndirectedEdge] 111, 15 \[UndirectedEdge] 66, 16 \[UndirectedEdge] 33, 16 \[UndirectedEdge] 38, 18 \[UndirectedEdge] 35, 18 \[UndirectedEdge] 68, 19 \[UndirectedEdge] 37, 19 \[UndirectedEdge] 39, 21 \[UndirectedEdge] 47, 21 \[UndirectedEdge] 63, 22 \[UndirectedEdge] 49, 23 \[UndirectedEdge] 50, 24 \[UndirectedEdge] 103, 25 \[UndirectedEdge] 48, 26 \[UndirectedEdge] 57, 26 \[UndirectedEdge] 110, 27 \[UndirectedEdge] 78, 27 \[UndirectedEdge] 112, 28 \[UndirectedEdge] 85, 28 \[UndirectedEdge] 98, 29 \[UndirectedEdge] 70, 29 \[UndirectedEdge] 71, 29 \[UndirectedEdge] 82, 29 \[UndirectedEdge] 87, 30 \[UndirectedEdge] 34, 30 \[UndirectedEdge] 79, 30 \[UndirectedEdge] 115, 32 \[UndirectedEdge] 72, 34 \[UndirectedEdge] 80, 34 \[UndirectedEdge] 113, 35 \[UndirectedEdge] 44, 36 \[UndirectedEdge] 45, 36 \[UndirectedEdge] 73, 37 \[UndirectedEdge] 93, 39 \[UndirectedEdge] 88, 41 \[UndirectedEdge] 117, 43 \[UndirectedEdge] 94, 44 \[UndirectedEdge] 77, 44 \[UndirectedEdge] 114, 45 \[UndirectedEdge] 74, 46 \[UndirectedEdge] 111, 47 \[UndirectedEdge] 91, 49 \[UndirectedEdge] 101, 51 \[UndirectedEdge] 83, 52 \[UndirectedEdge] 76, 54 \[UndirectedEdge] 62, 58 \[UndirectedEdge] 67, 63 \[UndirectedEdge] 75, 67 \[UndirectedEdge] 104, 70 \[UndirectedEdge] 118, 71 \[UndirectedEdge] 86, 71 \[UndirectedEdge] 106, 72 \[UndirectedEdge] 90, 72 \[UndirectedEdge] 99, 73 \[UndirectedEdge] 100, 75 \[UndirectedEdge] 92, 79 \[UndirectedEdge] 89, 81 \[UndirectedEdge] 112, 83 \[UndirectedEdge] 95, 84 \[UndirectedEdge] 96, 86 \[UndirectedEdge] 107, 96 \[UndirectedEdge] 97, 96 \[UndirectedEdge] 98, 100 \[UndirectedEdge] 119, 105 \[UndirectedEdge] 109, 108 \[UndirectedEdge] 109, 109 \[UndirectedEdge] 113, 112 \[UndirectedEdge] 116, 118 \[UndirectedEdge] 120};

(* 42 + 7 = 49 *)
(* treeEdgeList = {1 \[UndirectedEdge] 8, 1 \[UndirectedEdge] 12, 1 \[UndirectedEdge] 14, 1 \[UndirectedEdge] 19, 1 \[UndirectedEdge] 29, 1 \[UndirectedEdge] 52, 1 \[UndirectedEdge] 53, 1 \[UndirectedEdge] 54, 1 \[UndirectedEdge] 59, 1 \[UndirectedEdge] 61, 1 \[UndirectedEdge] 65, 1 \[UndirectedEdge] 102, 2 \[UndirectedEdge] 3, 2 \[UndirectedEdge] 5, 2 \[UndirectedEdge] 6, 2 \[UndirectedEdge] 10, 2 \[UndirectedEdge] 110, 3 \[UndirectedEdge] 15, 3 \[UndirectedEdge] 27, 3 \[UndirectedEdge] 30, 3 \[UndirectedEdge] 31, 3 \[UndirectedEdge] 51, 3 \[UndirectedEdge] 60, 4 \[UndirectedEdge] 7, 4 \[UndirectedEdge] 19, 4 \[UndirectedEdge] 20, 4 \[UndirectedEdge] 32, 4 \[UndirectedEdge] 36, 4 \[UndirectedEdge] 40, 5 \[UndirectedEdge] 41, 6 \[UndirectedEdge] 42, 6 \[UndirectedEdge] 56, 7 \[UndirectedEdge] 22, 7 \[UndirectedEdge] 43, 8 \[UndirectedEdge] 9, 8 \[UndirectedEdge] 18, 8 \[UndirectedEdge] 21, 8 \[UndirectedEdge] 104, 9 \[UndirectedEdge] 11, 9 \[UndirectedEdge] 64, 10 \[UndirectedEdge] 55, 11 \[UndirectedEdge] 69, 12 \[UndirectedEdge] 3, 12 \[UndirectedEdge] 13, 12 \[UndirectedEdge] 16, 12 \[UndirectedEdge] 28, 13 \[UndirectedEdge] 111, 15 \[UndirectedEdge] 66, 16 \[UndirectedEdge] 33, 16 \[UndirectedEdge] 38, 17 \[UndirectedEdge] 22, 18 \[UndirectedEdge] 35, 18 \[UndirectedEdge] 68, 19 \[UndirectedEdge] 37, 19 \[UndirectedEdge] 39, 20 \[UndirectedEdge] 23, 21 \[UndirectedEdge] 47, 21 \[UndirectedEdge] 63, 22 \[UndirectedEdge] 49, 23 \[UndirectedEdge] 50, 25 \[UndirectedEdge] 48, 25 \[UndirectedEdge] 110, 26 \[UndirectedEdge] 57, 27 \[UndirectedEdge] 78, 27 \[UndirectedEdge] 112, 28 \[UndirectedEdge] 85, 28 \[UndirectedEdge] 98, 29 \[UndirectedEdge] 70, 29 \[UndirectedEdge] 71, 29 \[UndirectedEdge] 82, 29 \[UndirectedEdge] 87, 30 \[UndirectedEdge] 79, 30 \[UndirectedEdge] 115, 32 \[UndirectedEdge] 72, 34 \[UndirectedEdge] 41, 34 \[UndirectedEdge] 80, 34 \[UndirectedEdge] 113, 35 \[UndirectedEdge] 44, 36 \[UndirectedEdge] 45, 36 \[UndirectedEdge] 73, 37 \[UndirectedEdge] 93, 39 \[UndirectedEdge] 88, 40 \[UndirectedEdge] 94, 41 \[UndirectedEdge] 117, 44 \[UndirectedEdge] 77, 45 \[UndirectedEdge] 74, 47 \[UndirectedEdge] 91, 51 \[UndirectedEdge] 83, 52 \[UndirectedEdge] 76, 54 \[UndirectedEdge] 62, 60 \[UndirectedEdge] 84, 63 \[UndirectedEdge] 75, 67 \[UndirectedEdge] 58, 68 \[UndirectedEdge] 114, 69 \[UndirectedEdge] 101, 70 \[UndirectedEdge] 118, 71 \[UndirectedEdge] 86, 71 \[UndirectedEdge] 106, 72 \[UndirectedEdge] 90, 75 \[UndirectedEdge] 92, 79 \[UndirectedEdge] 89, 82 \[UndirectedEdge] 105, 83 \[UndirectedEdge] 95, 85 \[UndirectedEdge] 99, 87 \[UndirectedEdge] 100, 88 \[UndirectedEdge] 107, 96 \[UndirectedEdge] 97, 98 \[UndirectedEdge] 96, 100 \[UndirectedEdge] 119, 103 \[UndirectedEdge] 24, 103 \[UndirectedEdge] 104, 104 \[UndirectedEdge] 67, 108 \[UndirectedEdge] 109, 110 \[UndirectedEdge] 26, 111 \[UndirectedEdge] 46, 112 \[UndirectedEdge] 81, 112 \[UndirectedEdge] 116, 113 \[UndirectedEdge] 109, 118 \[UndirectedEdge] 120}; *)

selectedEdges = { treeEdgeList };

processedNeighbors = <||>;

iterationLimit = 30;
truncationLimit = 30;

For[iteration = 1, iteration <= iterationLimit, iteration++,
	Print[DateString["ISODateTime"] <> " Iteration " <> IntegerString[iteration] ];
	(* neighborDistance = Ceiling[iteration/5]; *)
	neighborDistance = 1;

	neighbors = Apply[Union, Map[getNeighborEdgeLists[#, graphEdgeList, neighborDistance]&, selectedEdges]];
	Print["neighbor count " <> IntegerString[Length[neighbors]] ];
	bestEdgeList = {};

	For[neighborId = 1, neighborId <= Length[neighbors], neighborId++,
		If[Mod[neighborId, 100] == 0, Print["Processing neighborId " <> IntegerString[neighborId]]];
		If[neighborId > 1000, Break[]];
		neighbor = neighbors[[neighborId]];
		spanningTree = FindSpanningTree[Graph[neighbor]];
		tree = GraphTree[spanningTree, 41];
		rootCellId = TreeData[tree];

		rotationSchedule = {};

		rotationSchedule = buildSchedule[tree, rotationSchedule, 1];
		maxLevel = Max[Map[#[[3]]&, rotationSchedule ]];
		unfoldPercents = {-1};
		weights = {1};

		foldResult = testFold[cells, rotationSchedule, Table[-1, {k, 1, maxLevel}]];

		score = Length[foldResult[[1]]] + foldResult[[2]][[1]][[1]];

		distinctCellsCounts = {score};
		target = 33 + 3;

		If[Dot[distinctCellsCounts, weights] < maxCellCount,
			maxCellCount = Dot[distinctCellsCounts, weights];
			Print[DateString["ISODateTime"] <> " Iteration " <> IntegerString[iteration] <> " Updated maxCellCount to " <> IntegerString[maxCellCount] ];
			Print[distinctCellsCounts];
			Print["resetting bestEdgeList"];
			bestEdgeList = {};
			Print[neighbor];
			Print[rotationSchedule];
			Print[rootCellId];
		];

		If[Dot[distinctCellsCounts, weights] == maxCellCount,
			Print[DateString["ISODateTime"] <> " Iteration " <> IntegerString[iteration] <> " neighborDistance:" <> IntegerString[neighborDistance] <> " Keeping maxCellCount as " <> IntegerString[maxCellCount] <> " processedNeighbors count: " <> IntegerString[Length[processedNeighbors]] ];
			Print[distinctCellsCounts];
			Print[foldResult];
			Print[{Length[foldResult[[1]]], foldResult[[2]][[1]][[1]] }];

			(* Print["rootCellId: " <> IntegerString[rootCellId] ]; *)
			(* Print[neighbor]; *)

			If[Total[distinctCellsCounts] == target * Length[unfoldPercents],
				Print["Found the worst net"];

				Print["rootCellId: " <> IntegerString[rootCellId] ];
				Print[neighbor];

				Exit[];
			];

(* 				If[Total[distinctCellsCounts[[{1, 3}]]] == 32 * 2,
				Print["Found a less ideal net. The first two fold shapes are complete"];
				Exit[];
			];
*)
			If[KeyExistsQ[processedNeighbors, neighbor] == False,
				AppendTo[bestEdgeList, neighbor];
			];
		];

		If[KeyExistsQ[processedNeighbors, neighbor] == False,
			processedNeighbors[neighbor] = True;
		];
	];


	Print["End of iteration. bestEdgeList count: " <> IntegerString[Length[bestEdgeList]] <> " processedNeighbors count: " <> IntegerString[Length[processedNeighbors]]];
	selectedEdges = RandomSample[bestEdgeList, Min[Length[bestEdgeList], truncationLimit]];

];



Exit[];

(* Print[VertexCount[combinedGraph]]; *)
highlightedCellIds = VertexList[combinedGraph]//Sort;

If[TreeGraphQ[combinedGraph] == False,
	Continue[];
	Print["unexpected: combined graph is not a tree"];
	Exit[];
];

combinedTree = GraphTree[combinedGraph, 41];
rotationSchedule = {};
rotationSchedule = buildSchedule[combinedTree, rotationSchedule, 1];
maxLevel = Max[Map[#[[3]]&, rotationSchedule ]];
foldPercents = Table[-1, {k, maxLevel}];
rotatedCells = foldCells[cells, rotationSchedule, foldPercents];




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
- if we focus on only one orbit of 10 cells from 120-cell, they can be folded into 10 distinct cells in grand 120-cell
- if we focus on 6 orbits, 60 cells in total, they can be founded to up to 52 cells.
- 2 orbits, 41 and 79: 20 cells
- 3 orbits, 41, 5, 6: 30 cells
- 4 orbits, 41, 42, 30, 79: 38 cells. already conflicting

another attempt:
orbit 7 from 120-cell folds into grand 120-cell as an orbit using the same Hopf fibration.

orbit 4 from 120-cell doesn't fold into grand 120-cell as an orbit using the same Hopf fibration.

Example. After shifting origin:
orbit 7:
{0., 0., 0.36327126, 0.5}
{0., 0., -0.58778525, 0.19098301}
{0., 0., -0.58778525, -0.19098301}
{0., 0., 0., 0.61803399}
{0., 0., 0., -0.61803399}
{0., 0., 0.58778525, -0.19098301}
{0., 0., 0.58778525, 0.19098301}
{0., 0., -0.36327126, 0.5}
{0., 0., -0.36327126, -0.5}
{0., 0., 0.36327126, -0.5}

orbit 4
{-0.16245985000000002, 0.5, -0.32491970000000003, 0.}
{-0.16245985000000002, -0.5, -0.32491970000000003, 0.}
{0.26286556, -0.19098301, 0.5257311100000001, 0.}
{0.26286556, 0.19098301, 0.5257311100000001, 0.}
{0., -0.61803399, 0., 0.}
{0., 0.61803399, 0., 0.}
{-0.26286556, 0.19098301, -0.5257311100000001, 0.}
{-0.26286556, -0.19098301, -0.5257311100000001, 0.}
{0.16245985000000002, 0.5, 0.32491970000000003, 0.}
{0.16245985000000002, -0.5, 0.32491970000000003, 0.}


Why orbits are messed up after folding?

before folding:
{0.32491970000000003, 1., 1.37638192, -1.}
{-0.32491970000000003, 1., 1.70130162, 0.}
{-0.85065081, 0.61803399, 1.37638192, 1.}
{-1.0514622200000001, 0., 0.5257311100000001, 1.61803399}
{-0.85065081, -0.61803399, -0.5257311100000001, 1.61803399}
{-0.32491970000000003, -1., -1.37638192, 1.}
{0.32491970000000003, -1., -1.70130162, 0.}
{0.85065081, -0.61803399, -1.37638192, -1.}
{1.0514622200000001, 0., -0.5257311100000001, -1.61803399}
{0.85065081, 0.61803399, 0.5257311100000001, -1.61803399}
otherOrbitNorm before folding
{0.26286555605956685, -0.8090169943749475, 0.5257311121191337}


{-1.37638192, -1., -0.85065081, -0.61803399}
{1.70130162, 0., -0.85065081, -0.61803399}
{0.32491970000000003, 1., 1.37638192, 1.}
{-0.85065081, 0.61803399, 1.37638192, 1.}
{1.90211303, 0.61803399, 0., 0.}
{-1.90211303, -0.61803399, 0., 0.}
{-0.32491970000000003, -1., -1.37638192, -1.}
{0.85065081, -0.61803399, -1.37638192, -1.}
{-1.70130162, 0., 0.85065081, 0.61803399}
{1.37638192, 1., 0.85065081, 0.61803399}
otherOrbitNorm after folding
{0.26286555605956635, -0.8090169943749479, 0.5257311121191329}



 *)