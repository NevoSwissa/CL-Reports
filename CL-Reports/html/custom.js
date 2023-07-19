let playerID = null;
let playerLeaderBoardName = null;
let timeoutInfo = null;
let godPermission = false;
let timeoutInterval;
let currentPage = 1;
let totalPages = 1;
const body = document.body;
const toggleBtn = document.querySelector('#toggle-btn');
const toggleBtn2 = document.getElementById('toggle-btn2');
const bringButton = document.querySelector('.button-container .button:nth-child(1)');
const goToButton = document.querySelector('.button-container .button:nth-child(2)');
const resolveButton = document.querySelector('.button-container .button:nth-child(3)');

$(document).ready(function() {
  $('.white-box').hide();
  $('.admin-container').hide();
  $('.help-container').hide();
  $('.leaderboard-container').hide();
});

bringButton.addEventListener('click', function() {
  bringAction(getReportId());
});

goToButton.addEventListener('click', function() {
  goToAction(getReportId());
});

resolveButton.addEventListener('click', function() {
  resolveAction(getReportId());
})

function hasGodPermission(callback) {
  $.post(`https://${GetParentResourceName()}/GetPermission`, JSON.stringify({}), function(result) {
    if (result) {
      callback(result);
    }
  });
}

function fetchReports() {
  $.post(`https://${GetParentResourceName()}/GetReports`, JSON.stringify({}), function(result) {
    if (Array.isArray(result)) {
      const activeReports = result;
      updateReportList(activeReports);
    }
  });
}

function fetchTopAdmins() {
  $('.admin-entry').remove();
  $('.no-admin-message').remove();

  $.post(`https://${GetParentResourceName()}/GetTopAdmins`, JSON.stringify({}), function(result) {
    if (result && result.length > 0) {
      result.sort(function(a, b) {
        return b.reports - a.reports;
      });

      result.forEach(function(admin, index) {
        var adminContainer = $('<div>').addClass('admin-entry');
        var adminIcon = $('<div>').addClass('admin-icon').html('<i class="fa-solid fa-' + (index + 1) + '"></i>'); 
        var adminName = $('<div>').addClass('admin-name').text(admin.adminName);
        var adminReports = $('<div>').addClass('admin-reports').text('with ' + admin.reports + ' reports this week.');

        adminContainer.append(adminIcon, adminName, adminReports);
        $('#leaderboard-list').append(adminContainer);
      });
    } else {
      var message = $('<div>').addClass('no-admin-message').text('No top admins this week.');
      $('.leaderboard-white-box').append(message);
      $('#leaderboard-container').hide();
    }
  });
}

function getReportId() {
  return $('#report-id').text().trim();
}

function bringAction(reportId) {
  $.post(`https://${GetParentResourceName()}/ButtonAction`, JSON.stringify({
    action: 'bring',
    reportid: reportId,
  }));
}

function goToAction(reportId) {
  $.post(`https://${GetParentResourceName()}/ButtonAction`, JSON.stringify({
    action: 'goto',
    reportid: reportId,
  }));
}

function resolveAction(reportId) {
  clearTimeout(timeoutInterval);
  $.post(`https://${GetParentResourceName()}/ButtonAction`, JSON.stringify({
    action: 'resolve',
    reportid: reportId,
  }));
}

function getReportStatus(playerid, callback) {
  $.post(`https://${GetParentResourceName()}/GetReportStatus`, JSON.stringify({
    playerid: playerid,
  }), function(result) {
    callback(result);
  });
}

function updatePaginationButtons() {
  const buttonContainer = document.querySelector('.page-container');
  buttonContainer.innerHTML = '';

  const maxPageButtons = 1;
  const startPage = Math.max(1, currentPage - maxPageButtons);
  const endPage = Math.min(totalPages, currentPage + maxPageButtons);

  if (startPage > 1) {
    const previousButton = document.createElement('button');
    previousButton.innerHTML = '<i class="fa-solid fa-chevron-left"></i>';
    previousButton.addEventListener('click', function () {
      currentPage--;
      fetchReports();
    });
    buttonContainer.appendChild(previousButton);
  }

  const crownIcon = document.createElement('i');
  crownIcon.classList.add('leaderboard-button');
  crownIcon.classList.add('fa-solid');
  crownIcon.classList.add('fa-crown');

  if (hasGodPermission) {
    crownIcon.addEventListener('click', function() {
      ShowBoardInterface(playerLeaderBoardName);
    });
    buttonContainer.appendChild(crownIcon);
  }

  for (let i = startPage; i <= endPage; i++) {
    const button = document.createElement('button');
    button.textContent = i;
    button.addEventListener('click', function () {
      currentPage = i;
      fetchReports();
    });
    buttonContainer.appendChild(button);
  }

  if (endPage < totalPages) {
    const nextButton = document.createElement('button');
    nextButton.innerHTML = '<i class="fa-solid fa-chevron-right"></i>';
    nextButton.addEventListener('click', function () {
      currentPage++;
      fetchReports();
    });
    buttonContainer.appendChild(nextButton);
  }

  const buttons = buttonContainer.getElementsByTagName('button');
  buttons[currentPage - 1].classList.add('current-page');
}

function updateReportList(activeReports) {
  $('#report-list').empty();

  if (activeReports.length === 0) {
    const noReportsMessage = document.createElement('p');
    noReportsMessage.textContent = 'No reports yet.';
    noReportsMessage.classList.add('no-reports-message');
    $('#report-list').append(noReportsMessage);
  } else {
    const reportsPerPage = 5;
    totalPages = Math.ceil(activeReports.length / reportsPerPage);

    activeReports.sort((a, b) => b.id - a.id);

    let startIndex = (currentPage - 1) * reportsPerPage;
    let endIndex = Math.min(startIndex + reportsPerPage, activeReports.length);

    for (let i = startIndex; i < endIndex; i++) {
      const report = activeReports[i];
      const reportItem = createReportItem(report);
      $('#report-list').append(reportItem);
    }
  }

  updatePaginationButtons();
}

function createReportItem(report) {
  const reportItem = document.createElement('div');
  reportItem.classList.add('report-item');
  
  const idElement = document.createElement('p');
  idElement.textContent = report.id;
  
  const playerElement = document.createElement('p');
  playerElement.textContent = report.playerName;
  
  const reportedElement = document.createElement('p');
  
  if (report.reportReason === 'question') {
    reportedElement.textContent = 'A Question';
  } else if (report.reportReason === 'bug') {
    reportedElement.textContent = 'A Bug';
  } else if (report.reportReason === 'player') {
    reportedElement.textContent = 'A Player';
  } else {
    reportedElement.textContent = report.reportReason;
  }
  
  const actionElement = document.createElement('button');
  actionElement.textContent = "Deal";
  actionElement.addEventListener('click', function() {
    ShowHelpInterface(report.playerName, report.id, report.reportReason, report.reportTitle, report.reportDescription);
  });
  
  reportItem.appendChild(idElement);
  reportItem.appendChild(playerElement);
  reportItem.appendChild(reportedElement);
  reportItem.appendChild(actionElement);
  
  return reportItem;
}

function ShowHelpInterface(playerName, reportId, reportIssue, reportTitle, reportDesc) {
  const helpIcon = $('.help-profile');
  const profileIcon = helpIcon.find('.profile-icon');
  const titleInput = $('.help-container .title-input');
  const descInput = $('.help-container .description-input');

  if (reportIssue === 'question') {
    profileIcon.removeClass().addClass('fa-solid fa-question profile-icon');
    helpIcon.attr('data-tooltip', playerName + ' reported a question');
  } else if (reportIssue === 'bug') {
    profileIcon.removeClass().addClass('fa-solid fa-bug profile-icon');
    helpIcon.attr('data-tooltip', playerName + ' reported a bug');
  } else if (reportIssue === 'player') {
    profileIcon.removeClass().addClass('fa-solid fa-user-secret profile-icon');
    helpIcon.attr('data-tooltip', playerName + ' reported a player');
  } else {
    profileIcon.removeClass().addClass('fa-solid fa-triangle-exclamation profile-icon');
    helpIcon.attr('data-tooltip', playerName + ' reported an issue');
  }

  $('#player-name3').text(playerName);
  $('#report-id').html('<i class="fa-solid fa-hashtag"></i>' + reportId);

  titleInput.val(reportTitle).prop('readonly', true);
  descInput.val(reportDesc).prop('readonly', true);

  $('.help-container').fadeIn(250);
  $('.admin-container').addClass('blur');
}

function ShowBoardInterface(playerName) {
  $('#player-name4').text(playerName);
  $('.leaderboard-container').fadeIn(500);
  $('.admin-container').addClass('blur');
  fetchTopAdmins()
}

function ShowAdminInterface(playerName, activeReports) {
  $('#player-name2').text(playerName);
  $('.admin-container').fadeIn(500).removeClass('blur');
  updateReportList(activeReports)
}

function ShowUserInterface(playerName) {
  $('#player-name').text(playerName);
  $('.white-box').fadeIn(500);
}

function HideAdminInterface() {
  $('.admin-container').fadeOut(500);
  godPermission = false
  playerLeaderBoardName = null
  $.post(`https://${GetParentResourceName()}/HideAdminInterface`);
}

function HideHelpInterface() {
  $('.help-container').fadeOut(250);
  $('.admin-container').removeClass('blur');
}

function HideUserInterface() {
  $('#white-box').fadeOut(500, function() {
    $(this).hide();
    resetInputs();
  });
  playerID = null;
  $.post(`https://${GetParentResourceName()}/HideUserInterface`);
}

function HideBoardInterface() {
  $('.admin-container').removeClass('blur');
  $('.leaderboard-container').fadeOut(500);
}

function closeUI() {
  if ($('.white-box').is(':visible')) {
    HideUserInterface();
  } else if ($('.help-container').is(':visible')) {
    HideHelpInterface();
  } else if ($('.leaderboard-container').is(':visible')) {
    HideBoardInterface();
  } else if ($('.admin-container').is(':visible')) {
    HideAdminInterface();
  }
}

function resetInputs() {
  const dropdown = document.querySelector('.dropdown-input');
  const titleInput = document.querySelector('.title-input');
  const descriptionInput = document.querySelector('.description-input');

  dropdown.value = '';
  titleInput.value = '';
  descriptionInput.value = '';
}

function reportIssue() {
  getReportStatus(playerID, function(status) {
    if (status) {
      $.post(`https://${GetParentResourceName()}/SendNotify`, JSON.stringify({
        message: 'You already have an active report. Please wait until your report is dealt with or when the timeout runs out.',
        type: 'error',
      }));
    } else {
      const dropdown = document.querySelector('.dropdown-input');
      const selectedOption = dropdown.value;

      const titleInput = document.querySelector('.title-input');
      const title = titleInput.value;

      const descriptionInput = document.querySelector('.description-input');
      const description = descriptionInput.value;

      if (!dropdown.checkValidity() || !titleInput.checkValidity() || !descriptionInput.checkValidity()) {
        $.post(`https://${GetParentResourceName()}/SendNotify`, JSON.stringify({
          message: 'Please fill in all the required fields.',
          type: 'error',
        }));
        return;
      }

      $.post(`https://${GetParentResourceName()}/ReportInfo`, JSON.stringify({
        type: selectedOption,
        reportTitle: title,
        reportDescription: description,
        reporterID: playerID,
      }));

      dropdown.value = '';
      titleInput.value = '';
      descriptionInput.value = '';

      HideUserInterface();

      if (timeoutInfo.Enable && timeoutInfo.Time > 0) {
        timeoutInterval = setTimeout(function() {
          $.post(`https://${GetParentResourceName()}/ReportTimeout`);
        }, timeoutInfo.Time * 60 * 1000);
      }
    }
  });
}

$('.close-icon').click(function() {
  closeUI();
});

toggleBtn.addEventListener('click', () => {
  toggleBtn.classList.toggle('active');
  if (toggleBtn.classList.contains('active')) {
    $.post(`https://${GetParentResourceName()}/SendNotify`, JSON.stringify({
      message: 'Report notifications enabled. You will be notified when new reports are submitted.',
      type: 'success',
    }));
    $.post(`https://${GetParentResourceName()}/SetReceiveReports`, JSON.stringify({
      receiveReports: true
    }));
  } else {
    $.post(`https://${GetParentResourceName()}/SendNotify`, JSON.stringify({
      message: 'Report notifications disabled. You will not be notified about new reports.',
      type: 'primary',
    }));
    $.post(`https://${GetParentResourceName()}/SetReceiveReports`, JSON.stringify({
      receiveReports: false
    }));
  }
});

toggleBtn2.addEventListener('click', () => {
  toggleBtn2.classList.toggle('active');
  body.classList.toggle('dark-mode');
});

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    closeUI();
  }
});

window.addEventListener('message', function(event) {
  switch(event.data.action) {
    case "ShowUserInterface":
      playerID = event.data.playerID;
      timeoutInfo = event.data.timeout;
      ShowUserInterface(event.data.playerName);
    break;
    case "ShowAdminInterface":
      playerLeaderBoardName = event.data.playerName
      ShowAdminInterface(event.data.playerName, event.data.activeReports);
      hasGodPermission(function(hasPermission) {
        if (hasPermission) {
          godPermission = true
        }
      });
    break;
    case "HideHelpInterface":
      HideHelpInterface();
    break;
    case "Refresh":
      updateReportList(event.data.activeReports);
    break;
  }
});