from time import sleep

import yaml
# from numpy.f2py.crackfortran import endifs
import os
import docker
from docker.types import LogConfig
# from prompt_toolkit.utils import to_str


# docker run -t -i --rm --ipc=host -v /home/wasteantadmin/Constructor-Robotics/Tim/ros_ws/cache/humble/build:/home/tim-external/ros_ws/build \
#                                  -v /home/wasteantadmin/Constructor-Robotics/Tim/ros_ws/cache/humble/install:/home/tim-external/ros_ws/install \
#                                 -v /home/wasteantadmin/Constructor-Robotics/Tim/ros_ws/cache/humble/log:/home/tim-external/ros_ws/log \
#                                 -v /home/wasteantadmin/Constructor-Robotics/Tim/ros_ws/configFiles:/home/tim-external/ros_ws/configFiles \
#                                 -v /home/wasteantadmin/Constructor-Robotics/Tim/ros_ws/src:/home/tim-external/ros_ws/src \
#                                 -v /home/wasteantadmin/Constructor-Robotics/Tim/dataFolder:/home/tim-external/dataFolder \
# computationimageodometry


# configFiles/predatorNothing.yaml 128 0 16 48 0.001 0.001 2 None train
# configFiles/predatorNothing.yaml 64 1 8 24 0.01 0.01 2
# configFiles/predatorNothing.yaml 32 1 4 12 0.01 0.001 2 None train



# example config setting: configFiles/predatorNothing.yaml 64 1 8 24 0.01 0.01 2
currentNumberScriptStartPoint = 0


# docker build -t computationimageodometry -f DockerfileBaseARM .
# computerPath = '/home/deeprobotics'
computerPath = '/home/wasteantadmin/Constructor-Robotics/Tim'


clahe = [0]


# N = [32,64]
N = [32,64,128]
normalization_factor = [2]

level_potential_rotation = [0.001]
level_potential_translation = [0.001]
noise = ["None","low","high"]
dataType = ["val"]
# configFiles/predatorNothing.yaml 32 0 4 12 0.001 0.001 2 high train {str(noise_)} {str(dataType_)

def quoted_presenter(dumper, data):
    return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='"')

yaml.add_representer(str, quoted_presenter)

lc = LogConfig(type=LogConfig.types.JSON, config={
    'max-size': '1g',
    'labels': 'production_status,geo'
})

client = docker.from_env()
currentNumberScript = 0
for clahe_ in clahe:
    for normalization_factor_ in normalization_factor:
        for level_potential_rotation_ in level_potential_rotation:
            for level_potential_translation_ in level_potential_translation:
                for N_ in N:
                    for noise_ in noise:
                        for dataType_ in dataType:
                            if currentNumberScript<currentNumberScriptStartPoint:
                                print("skipping number: ", currentNumberScript)
                                currentNumberScript = currentNumberScript+1
                                continue
                            r_min = 0
                            r_max = 0
                            if N_ == 32:
                                r_min = 4
                                r_max = 12
                            elif N_ == 64:
                                r_min = 8
                                r_max =24
                            elif N_ == 128:
                                r_min = 16
                                r_max =48


                            print("Configuring everything")


                            bashFileNameHost = computerPath+'/ros_ws/src/fsregistration/pythonScripts/matchingProfiling3D/bashFilesDockerGenerated/myscript'+str(currentNumberScript)+'.sh'
                            bashFileNameDocker = '/home/tim-external/ros_ws/src/fsregistration/pythonScripts/matchingProfiling3D/bashFilesDockerGenerated/myscript'+str(currentNumberScript)+'.sh'

                            with open(bashFileNameHost, "w") as file:
                                file.write("#!/bin/bash\n")
                                file.write("export ROS_LOCALHOST_ONLY=1\n")
                                file.write("export ROS_DOMAIN_ID="+str(currentNumberScript)+"\n")
                                file.write("source /opt/ros/humble/setup.bash\n")
                                file.write("source /home/tim-external/ros_ws/install/setup.bash\n")
                                file.write("ros2 run fsregistration ros2ServiceRegistrationFS3D & >/dev/null 2>&1\n")
                                file.write("\nsleep 10\n")
                                file.write("cd /home/tim-external/ros_ws/src/fsregistration/pythonScripts/matchingProfiling3D \n")
                                file.write(f"python3 testingSoftOnPredatorData.py configFiles/predatorNothing.yaml {str(N_)} {str(clahe_)} {str(r_min)} {str(r_max)} {str(level_potential_rotation_)} {str(level_potential_translation_)} {str(normalization_factor_)} {str(noise_)} {str(dataType_)} \n")

                            # Make the script executable

                            os.chmod(bashFileNameHost, 0o755)
                            print("created scripts and config files")
                            #run bash script in docker
                            while 1:
                                try:
                                    containers = client.containers.list()
                                    total_memory_usage = sum(
                                        stats['memory_stats']['usage'] / (1024 ** 3) for c in containers if
                                        (stats := c.stats(stream=False)))
                                    print("Memory usage is: ", total_memory_usage)

                                    if (total_memory_usage < 100 and len(containers)<10):
                                        print("running container number: ", currentNumberScript)
                                        container = client.containers.run(
                                            image='computationimageodometry',
                                            command=bashFileNameDocker,
                                            volumes={
                                                computerPath+'/ros_ws/cache/humble/build': {
                                                    'bind': '/home/tim-external/ros_ws/build', 'mode': 'cached'},
                                                computerPath+'/ros_ws/cache/humble/install': {
                                                    'bind': '/home/tim-external/ros_ws/install', 'mode': 'cached'},
                                                computerPath+'/ros_ws/cache/humble/log': {
                                                    'bind': '/home/tim-external/ros_ws/log', 'mode': 'cached'},
                                                computerPath+'/ros_ws/configFiles': {
                                                    'bind': '/home/tim-external/ros_ws/configFiles', 'mode': 'cached'},
                                                computerPath+'/ros_ws/src': {
                                                    'bind': '/home/tim-external/ros_ws/src','mode': 'cached'},
                                                computerPath+'/dataFolder': {
                                                    'bind': '/home/tim-external/dataFolder','mode': 'cached'},
                                                computerPath+'/ros_ws/myenv': {
                                                    'bind': '/home/tim-external/myenv','mode': 'cached'}
                                            },
                                            # network='devcontainer'+str(i)+'_net',
                                            detach=True,
                                            remove=True,
                                            log_config=lc
                                        )
                                        sleep(50)
                                        print("breaking out of while loop")
                                        break
                                except Exception as e:
                                    print(e)
                                    sleep(50)
                                sleep(100)
                            print("currentNumberScript done: ", currentNumberScript)
                            currentNumberScript=currentNumberScript+1



print("Everything Done")