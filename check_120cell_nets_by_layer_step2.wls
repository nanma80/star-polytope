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

	Print[highlightedCellIds];

	layerGroupByAfterFolding = 
	 GroupBy[Range[Length[shiftedSelectedCenters]], 
	  Round[normalized[shiftedSelectedCenters[[#]]][[4]], epsilon] &];
	Print["after folding, w-coordinates by layer"];
	Print[Sort[Keys[layerGroupByAfterFolding]]];

	layersAfterFolding = Map[If[KeyExistsQ[layerGroupByAfterFolding,#],layerGroupByAfterFolding[#], {}]&, originalDepths];
	layerLengths = Length/@layersAfterFolding;
	Print[layerLengths];
	If[KeyExistsQ[layerHistogramMap, layerLengths],
		AppendTo[ layerHistogramMap[layerLengths], candidateId],
		layerHistogramMap[layerLengths] = {candidateId}
	];
	Print["layerHistogramMap"];
	Print[layerHistogramMap];

	Print["others"];
	shiftedOtherCenters = shiftedCenters[[otherCells]];
	Print[otherCells];

	Print[shiftedOtherCenters];
	Print[shiftedOtherCenters//Length];
	Print[shiftedOtherCenters[[1]]];


	otherLayerGroupByAfterFolding = 
	 GroupBy[Range[Length[shiftedOtherCenters]], 
	  Round[normalized[shiftedOtherCenters[[#]]][[4]], epsilon] &];
	Print[otherLayerGroupByAfterFolding];

	otherLayersAfterFolding = Map[If[KeyExistsQ[otherLayerGroupByAfterFolding,#],otherLayerGroupByAfterFolding[#], {}]&, originalDepths];
	otherLayerLengths = Length/@otherLayersAfterFolding;
	Print[otherLayersAfterFolding];
	Print[otherLayerLengths];
	

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
		Print[rotationSchedule];
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
otherLayers = {3};
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

histogramMapLayer3 = <||>;

histogramMapLayer7 = <||>;

candidateIdsLayer7 = {4963, 4964, 5000, 5001, 5006, 5017, 5018, 5023, 5062, 5063, 5075, 5076, 5081, 5613, 5614, 5706, 5707, 5739, 5740, 5748, 5749, 5756, 5757, 5794, 5802, 5803, 5808, 5864, 5910, 5911, 5916, 5919, 5920, 5925, 6014, 6015, 6072, 6073, 6078, 6080, 6081, 6086, 6146, 6149, 6150, 6166, 6167, 6172, 6199, 6200, 6205, 6208, 6209, 6214, 6483, 6515, 6516, 6524, 6525, 6532, 6533, 6602, 6603, 6608, 6610, 6611, 6616, 10488, 10489, 10507, 10508, 10513, 10525, 10526, 10531, 10542, 10543, 10548, 10587, 10588, 11138, 11139, 11231, 11232, 11264, 11265, 11273, 11274, 11281, 11282, 11319, 11327, 11328, 11333, 11389, 11435, 11436, 11441, 11444, 11445, 11450, 11539, 11540, 11597, 11598, 11603, 11605, 11606, 11611, 11671, 11674, 11675, 11691, 11692, 11697, 11724, 11725, 11730, 11733, 11734, 11739, 12008, 12040, 12041, 12049, 12050, 12057, 12058, 12127, 12128, 12133, 12135, 12136, 12141, 17359, 17360, 17376, 17377, 17530, 17531, 17536, 17635, 17700, 17701, 17706, 17769, 17819, 17820, 17825, 18230, 18231, 18236, 18773, 18774, 18866, 18867, 18899, 18900, 18916, 18917, 18954, 18962, 18963, 18968, 19024, 19070, 19071, 19076, 19175, 19240, 19241, 19246, 19306, 19309, 19326, 19327, 19332, 19359, 19360, 19365, 19643, 19675, 19676, 19692, 19693, 19770, 19771, 19776};

candidateIdsLayer3 = {11528, 11531, 11534, 11595, 11597, 11600, 11603, 11605, 11608, 11612, 11615, 11798, 11801, 11804, 11851, 11853, 11856, 11859, 11864, 11868, 11871, 11926, 11928, 11931, 11934, 11966, 11973, 11976, 12017, 12019, 12022, 12025, 12057, 12060, 12064, 12067, 15128, 15131, 15134, 15167, 15170, 15173, 15197, 15200, 15203, 15205, 15208, 15212, 15215, 15852, 15855, 15858, 15919, 15921, 15924, 15927, 15929, 15932, 15936, 15939, 15973, 15976, 15979, 15988, 15991, 15994, 16025, 16027, 16030, 16033, 16055, 16057, 16060, 16063, 16065, 16068, 16072, 16075, 16122, 16125, 16128, 16175, 16177, 16180, 16183, 16188, 16192, 16195, 16250, 16252, 16255, 16258, 16290, 16297, 16300, 16341, 16343, 16346, 16349, 16381, 16384, 16388, 16391, 16884, 16887, 16890, 16938, 16941, 16944, 16968, 16971, 16974, 16976, 16979, 16983, 16986, 17623, 17626, 17629, 17690, 17692, 17695, 17698, 17700, 17703, 17707, 17710, 17744, 17747, 17750, 17759, 17762, 17765, 17796, 17798, 17801, 17804, 17826, 17828, 17831, 17834, 17836, 17839, 17843, 17846, 17893, 17896, 17899, 17946, 17948, 17951, 17954, 17959, 17963, 17966, 18021, 18023, 18026, 18029, 18061, 18068, 18071, 18112, 18114, 18117, 18120, 18152, 18155, 18159, 18162, 19163, 19166, 19169, 19230, 19232, 19235, 19238, 19247, 19250, 19433, 19436, 19439, 19652, 19654, 19657, 19660, 19699, 19702};

candidateIdsLayer5Partial = {};

exportData = <||>;
candidateIds = {};
If[otherLayers == {3}, candidateIds = candidateIdsLayer3 ];
If[otherLayers == {7}, candidateIds = candidateIdsLayer7 ];

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

(* 	Print[candidateId];
	Print[edgeGroups];
	Print[edgeGroups//Length];
	Print[shiftedSelectedCenters];
	Print[shiftedSelectedCenters//Length];
	Print[shiftedSelectedCenters[[1]]];
	Print[layerLengths];
	Exit[]; *)
];


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