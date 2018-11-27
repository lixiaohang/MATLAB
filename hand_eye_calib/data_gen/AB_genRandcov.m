function [A, B, X_new]=AB_genRandcov(X, noise, meanB, sdevB, num)
%Function to generate B is from a trajectory along an ellipsoid surface and corresponding A^is from a given X
    B = zeros(4,4,num+1);
    for i=1:num+1 %% n pair, n+1 poses
        B(:,:,i)=expm(se3_vec(sdevB*randn(6,1)+meanB));
        a=0;
    end
    
    for i=1:size(B,3)
        x_1=noise*randn(6,1);    
        x_2=noise*randn(6,1);

        X_new(:,:,i)=X*expm(se3_vec(x_1));
        X_new2(:,:,i)=X*expm(se3_vec(x_2));

        A(:,:,i)=X_new(:,:,i)*B(:,:,i)*X_new2(:,:,i)^-1;

    end

    X_new=cat(3, X_new, X_new2);

end