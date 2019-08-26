
function vpt = para_trans(R1,R2,v)
    A = logSO3(R1'*R2);
    Rpt = expSO3(A/2);
    if size(v,2) == 1
        vpt = invhat(R2'*R1*Rpt*hat(v)*Rpt);
    else
        vpt = invhat(R2'*R1*Rpt*(R1'*v)*Rpt);
    end
end