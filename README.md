How to run the simulation :



1\. **Run** *MONTE\_baseline.m* -> It generates the stochastic household demand based on a typical profile, solves Load-Flow and calculates the baseline KPIS.



2\. **Run** *MONTE\_uncontrolled.m* -> It generates the stochastic EV demand based on several uncertainties (intial SoC, Bat. Cap., etc), solves Load-Flow and calculates the KPIS for 3 different integration scenarios. This is considered as the uncoordinated charging.



3\. **Run** *dynamic\_pricing.m* -> The risk metrics of VUF and VD are calculated, and the dynamic pricing is built.



4\. **Run** *New\_data\_generation.m* -> It generates new EV data to insert unseen data for the controlled version, for evaluation of the mechanism effectiveness.



5\. **Run** *MONTE\_controlled.m* -> In this script the EV charging scheduling is obtained, the Load-Flow is solved for the new EV demand profiles and the KPIS for the controlled version are re-calculated.





The *.mlx* files + the *comprehensive\_review.m* are for the analysis of Power demand, losses, Voltages (plus VUF and VD), and voltage-risk metrics. 



The *compute\_CUF.m* and *iec\_VUF.m* are not used in this study. The scripts are for potential future work.



The remaining *.m* files are necessary for the workflow pipeline such as *API MATLAB-OPENDSS, interpolation, optimization function*, etc. 



The path of the script should be changed where needed.

