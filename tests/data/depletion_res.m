% Synthetic 3-step depletion _res.m (Serpent 2 layout, made-up values) used to
% test that burnup-dependent outputs come back as one value per burnup step.

% Increase counter:

if (exist('idx', 'var'));
  idx = idx + 1;
else;
  idx = 1;
end;

VERSION                   (idx, [1: 14])  = 'Serpent 2.1.32' ;
TOT_CPU_TIME              (idx, 1)        =  1.00000-01 ;
BURN_STEP                 (idx, 1)        = 0 ;
BURNUP                    (idx, [1:   2]) = [  0.00000E+00 0.00000E+00 ];
BURN_DAYS                 (idx, 1)        =  0.00000E+00 ;
ANA_KEFF                  (idx, [1:   6]) = [  1.30123E+00 0.00080  1.30123E+00 0.00080  8.00000E-03 0.02000 ];
IMP_KEFF                  (idx, [1:   2]) = [  1.30123E+00 0.00080 ];
COL_KEFF                  (idx, [1:   2]) = [  1.30123E+00 0.00080 ];
ABS_KEFF                  (idx, [1:   2]) = [  1.30123E+00 0.00080 ];
ABS_KINF                  (idx, [1:   2]) = [  1.30123E+00 0.00080 ];

% Increase counter:

if (exist('idx', 'var'));
  idx = idx + 1;
else;
  idx = 1;
end;

VERSION                   (idx, [1: 14])  = 'Serpent 2.1.32' ;
TOT_CPU_TIME              (idx, 1)        =  1.00001-01 ;
BURN_STEP                 (idx, 1)        = 1 ;
BURNUP                    (idx, [1:   2]) = [  1.00000E+00 1.00000E+00 ];
BURN_DAYS                 (idx, 1)        =  2.50000E+01 ;
ANA_KEFF                  (idx, [1:   6]) = [  1.27045E+00 0.00082  1.27045E+00 0.00082  8.00000E-03 0.02000 ];
IMP_KEFF                  (idx, [1:   2]) = [  1.27045E+00 0.00082 ];
COL_KEFF                  (idx, [1:   2]) = [  1.27045E+00 0.00082 ];
ABS_KEFF                  (idx, [1:   2]) = [  1.27045E+00 0.00082 ];
ABS_KINF                  (idx, [1:   2]) = [  1.27045E+00 0.00082 ];

% Increase counter:

if (exist('idx', 'var'));
  idx = idx + 1;
else;
  idx = 1;
end;

VERSION                   (idx, [1: 14])  = 'Serpent 2.1.32' ;
TOT_CPU_TIME              (idx, 1)        =  1.00002-01 ;
BURN_STEP                 (idx, 1)        = 2 ;
BURNUP                    (idx, [1:   2]) = [  1.00000E+01 1.00000E+01 ];
BURN_DAYS                 (idx, 1)        =  2.50000E+02 ;
ANA_KEFF                  (idx, [1:   6]) = [  1.19876E+00 0.00085  1.19876E+00 0.00085  8.00000E-03 0.02000 ];
IMP_KEFF                  (idx, [1:   2]) = [  1.19876E+00 0.00085 ];
COL_KEFF                  (idx, [1:   2]) = [  1.19876E+00 0.00085 ];
ABS_KEFF                  (idx, [1:   2]) = [  1.19876E+00 0.00085 ];
ABS_KINF                  (idx, [1:   2]) = [  1.19876E+00 0.00085 ];
