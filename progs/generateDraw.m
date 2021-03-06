% Copyright Andrew Binning 2013
% Please feel free to use and modify this code as you see if fit. If you
% use this code in any academic work, please cite 
% Andrew Binning, 2013.
% "Underidentified SVAR models: A framework for combining short and long-run restrictions with sign-restrictions,"
% Working Paper 2013/14, Norges Bank.
function B0inv = generateDraw(B0inv,K)
%==========================================================================
% Generates a draw that is consistent with the shock variance/covariance
% matrix. Based on Juan F. Rubio-Ramirez & Daniel F. Waggoner & Tao Zha, 2010.
% "Structural Vector Autoregressions: Theory of Identification and
% Algorithms for Inference," Review of Economic Studies, Oxford University Press, vol. 77(2), pages 665-696.
%
% inputs:
% C = initial impact matrix, usually from the cholesky decomposition of the
% forecast error variance decomposition
% k = number of dependent variables
% 
% outputs:
% C = new draw of the short run impact matrix
%==========================================================================
W = randn(K,K);
[Q,R] = qr(W);
% Normalization: make sure that diagonal of upper triangular R is positive
for ii = 1:K
    if R(ii,ii)<0
        Q(:,ii) = -Q(:,ii);
    end
end

B0inv = B0inv*Q;