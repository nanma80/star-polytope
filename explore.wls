#!/usr/bin/env wolframscript

(* 
shape = "test";
shape = "cell120";
shape = "cell600";
shape = "polytope_52_5_3";
shape = "polytope_5_52_5";
shape = "polytope_5_3_52";
shape = "polytope_52_5_52";
*)

shape = "test";

dataFolder = "data";

dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}]

Print["Reading data for " <> shape <> " from " <> dataFileName];

exportToPov = True;

Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

projectTo3d[vertex4d_] := {vertex4d[[1]], vertex4d[[2]], vertex4d[[3]]};
reflect[point_, mirror_] := FullSimplify[point - 2 * (point.mirror)/(mirror.mirror)*mirror];
doubleReflect[point_, mirror1_, mirror2_] := reflect[reflect[point, mirror1], mirror2];
getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
sameVertex[point1_, point2_] := point1 == point2;
sameCenter[edge1_, edge2_] := Total[edge1] == Total[edge2];
sameCellCenter[cell1_, cell2_] := getCellCenter[cell1] == getCellCenter[cell2];
getCellCenter[cell_] := Total[Flatten[cell, 1]];


outputFileName = shape <> ".png";
imageFolder = "output";
If[exportToPov, outputFileName = "pov_" <> outputFileName ];
outputFileName = FileNameJoin[{imageFolder, outputFileName}];
imageSize = {600, 450};

cells = Get[dataFileName];
Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];

cellCenters = Map[getCellCenter[#]&, cells];
cellCenters = SortBy[N[cellCenters], Last];

face = cells[[1]][[1]]//Simplify;

Print[face];
Print[face[[1]]-face[[2]]//Simplify//N];
Print[face[[2]]-face[[3]]//Simplify//N];
Print[Total[face]//Simplify//N ];

m = {face[[1]]-face[[2]], face[[2]]-face[[3]], Total[face]};
Print[m];
Print[NullSpace[m]//FullSimplify];

Print[cellCenters//N];
Print[Map[Norm, cellCenters]];

(*Print[cellCenters[[1]]//Simplify];*)

(*


centralCell = Select[cells, (getCellCenter[#][[1]] == 0 && getCellCenter[#][[2]] == 0 && getCellCenter[#][[3]] == 0 && getCellCenter[#][[4]] >= 0)&][[1]];

cell2 = Select[cells, (getCellCenter[#][[4]] == 15*(3 + Sqrt[5]))&];
Print[Length[cell2]];

c1=getCellCenter[centralCell]/60//Simplify;
c2=getCellCenter[cell2]/60//Simplify;

Print[Simplify[2*(c1-c2)]//N];

*)