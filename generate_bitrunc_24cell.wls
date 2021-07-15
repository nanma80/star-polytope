#!/usr/bin/env wolframscript

sameVertex[point1_, point2_] := point1 == point2;
sameCenter[edge1_, edge2_] := Total[edge1] == Total[edge2];
getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
getCellCenter[cell_] := Mean[Flatten[cell, 1]];
getTruncatedCell[cell_] := Module[
	{cellCenter, relativeVertices, halfVertices, xi, k, scale, truncatedCubeFaces, newFaces},
	cellCenter = getCellCenter[cell];
	relativeVertices = Map[# - cellCenter&, Union[Flatten[ cell, 1]]];
	halfVertices = Select[relativeVertices, arbitraryVector.# > 0 &];

	xi = Sqrt[2] - 1;
	k = 1/(2 + xi);
	scale = 2 + 3/Sqrt[2];

	truncatedCubeFaces = PolyhedronData["TruncatedCube", "FaceCoordinates"] * 2 * xi;

	newFaces = Table[
		Map[# + cellCenter &, truncatedCubeFaces[[i]].halfVertices * k] * scale,
		{i, 1, Length[truncatedCubeFaces]}
	]//FullSimplify//Expand;

	newFaces
];

dataFolder = "data";

shapes = {
	"polytope_3_4_3_alt",
	"polytope_3_4_3"
};

arbitraryVector = {Pi, Exp[1], 0.01, 3.3147};
allCellsImported = Map[Get[FileNameJoin[{dataFolder, # <> ".wl"}]]&, shapes];

originalCells = Join[ allCellsImported[[1]], allCellsImported[[2]] * Sqrt[2]];

cells = Map[ getTruncatedCell, originalCells];

faces = Union[Flatten[cells, 1], SameTest -> sameCenter];
edges = Union[Flatten[Map[getEdgesFromFace, faces], 1], SameTest -> sameCenter];
vertices = Union[ Flatten[faces,1], SameTest -> sameVertex];

Print["Numbers of cells, faces, edges, vertices:"];
Print[Map[Length, {cells, faces, edges, vertices}]];

dataFileName = FileNameJoin[{dataFolder, "bitruncated_3_4_3.wl"}];
If[FileExistsQ[dataFileName], DeleteFile[dataFileName]];
Save[dataFileName, cells];
Print["Saved cells to " <> dataFileName];
